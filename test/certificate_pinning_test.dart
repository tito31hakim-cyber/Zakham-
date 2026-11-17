import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:house_of_zakham/services/secure_http.dart';

/// Live certificate-pinning regression test.
///
/// Proves the pinned anchors in [SecureHttp] actually validate the real
/// `zakhamhouse.shop` chain (Let's Encrypt YE2 + Root YE + ISRG Root X2,
/// fetched 2026-11-17). A wrong or expired pin fails closed here
/// (HandshakeException) instead of shipping an app that cannot connect.
///
/// In this sandbox outbound traffic goes through an egress HTTP proxy,
/// so the test honours the `https_proxy` env var when present (CI and
/// real devices connect directly). Transient 5xx / network errors are
/// retried; a TLS failure fails immediately.
void main() {
  test(
    'pinned client validates the live zakhamhouse.shop chain',
    () async {
      final client = SecureHttp.createPinnedHttpClient();
      final proxy = Platform.environment['https_proxy'] ??
          Platform.environment['HTTPS_PROXY'];
      if (proxy != null && proxy.isNotEmpty) {
        final uri = Uri.parse(proxy);
        client.findProxy = (_) => 'PROXY ${uri.host}:${uri.port}';
        if (uri.userInfo.isNotEmpty) {
          final parts = uri.userInfo.split(':');
          client.authenticateProxy = (host, port, scheme, realm) async {
            client.addProxyCredentials(
              host,
              port,
              realm ?? '',
              HttpClientBasicCredentials(
                parts[0],
                parts.sublist(1).join(':'),
              ),
            );
            return true;
          };
        }
      }
      final io = IOClient(client);
      try {
        var lastStatus = 0;
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            final response = await io
                .get(Uri.parse('https://zakhamhouse.shop/api/health'))
                .timeout(const Duration(seconds: 15));
            lastStatus = response.statusCode;
            if (response.statusCode == 200) {
              final body =
                  jsonDecode(response.body) as Map<String, dynamic>;
              expect(body['ok'], isTrue);
              return; // Pin verified against the live chain.
            }
          } on HandshakeException catch (e) {
            fail('Certificate pin mismatch (handshake failed): $e');
          } on TlsException catch (e) {
            fail('Certificate pin mismatch (TLS failed): $e');
          } on SocketException {
            // Transient network failure — retry below.
          } on HttpException {
            // Transient — retry below.
          } on FormatException {
            // Non-JSON body (e.g. a transient 525 page) — retry below.
          }
          await Future<void>.delayed(const Duration(seconds: 2));
        }
        fail(
          'Could not verify the pin against the live site '
          '(last HTTP status: $lastStatus).',
        );
      } finally {
        io.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
