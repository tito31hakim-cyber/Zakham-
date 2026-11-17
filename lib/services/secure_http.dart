import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Pinned HTTPS client for the Zakham store API (`zakhamhouse.shop`).
///
/// The store sits behind a 90-day Let's Encrypt leaf that rotates on every
/// renewal, so the leaf itself is deliberately NOT pinned. Instead the
/// client trusts only these three anchors from the live chain
/// (fetched 2026-11-17, verified by SPKI SHA-256):
///   * YE2 (Let's Encrypt intermediate, primary anchor, expires 2028-09-02)
///     SPKI SHA-256: s/tdAOmUzd8syaTuqfgGvFcn6DzA5Cmb+Vby1ST+U3Y=
///   * Root YE (ISRG, backup anchor, expires 2032-09-02)
///     SPKI SHA-256: sCkq5UWXjg+7mKu9lMhhYF5bGLsy7VI/UNW3tccdR7w=
///   * ISRG Root X2 (second backup anchor, expires 2032-09-02)
///     SPKI SHA-256: diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI=
/// (Same SPKI values in android/.../network_security_config.xml.)
/// A renewal keeps the same intermediate, and a future intermediate
/// issued under Root YE / Root X2 still chains to a backup anchor, so
/// rotation does not break the app. If the whole hierarchy ever changes,
/// update these anchors and ship a new build BEFORE the old chain
/// expires — a wrong pin fails closed (no connection at all).
///
/// Only the store API services use this client. Other traffic
/// (google_fonts, Firebase) keeps the platform default trust store, so
/// pinning here cannot break font downloads or push registration.
/// `HttpOverrides.global` is intentionally NOT set.
class SecureHttp {
  SecureHttp._();

  // Let's Encrypt intermediate YE2 (primary anchor).
  static const _ye2Pem =
    'MIICjDCCAhGgAwIBAgIQTfOxXdbAeExQfNN7WObxFTAKBggqhkjOPQQDAzAuMQsw\n'
    'CQYDVQQGEwJVUzENMAsGA1UEChMESVNSRzEQMA4GA1UEAxMHUm9vdCBZRTAeFw0y\n'
    'NTA5MDMwMDAwMDBaFw0yODA5MDIyMzU5NTlaMDMxCzAJBgNVBAYTAlVTMRYwFAYD\n'
    'VQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQDEwNZRTIwdjAQBgcqhkjOPQIBBgUr\n'
    'gQQAIgNiAARxmrQzkdbEEL3MqXt3dJQttYc47axkdDTHud5TPqM2z5uSD5cmk0Wr\n'
    'HlWXvnlvqBLqiB34kluxIbmMyAiq3/YD6e80/vV259K8XQIdjFXloYOa0mIU71f7\n'
    'HQ09PvYDlw+jge4wgeswDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUF\n'
    'BwMBMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFLlZ8o7PIvCG0zdI/3YU\n'
    'GLqC2FWHMB8GA1UdIwQYMBaAFKPIJlqOoUzQNWP8myPIOq5W809WMDIGCCsGAQUF\n'
    'BwEBBCYwJDAiBggrBgEFBQcwAoYWaHR0cDovL3llLmkubGVuY3Iub3JnLzATBgNV\n'
    'HSAEDDAKMAgGBmeBDAECATAnBgNVHR8EIDAeMBygGqAYhhZodHRwOi8veWUuYy5s\n'
    'ZW5jci5vcmcvMAoGCCqGSM49BAMDA2kAMGYCMQDIcnw5dcZLN9ffynXnnkLD/itS\n'
    'JEycJPb3sRkzeqBowup7vOsAwaqoCnNn/jh9wycCMQCJM6CPlaOC4pQYYbJtVPYb\n'
    'DKrIb2EKk5NpOpE6/XttQYZV/3gilB9l+Cc/DOVwmyg=\n';

  // ISRG Root YE (backup anchor).
  static const _rootYePem =
    'MIICpjCCAiugAwIBAgIRAIchZfw0tuX7qK3Vs3BftTowCgYIKoZIzj0EAwMwTzEL\n'
    'MAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2VhcmNo\n'
    'IEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDIwHhcNMjYwNTEzMDAwMDAwWhcN\n'
    'MzIwOTAyMjM1OTU5WjAuMQswCQYDVQQGEwJVUzENMAsGA1UEChMESVNSRzEQMA4G\n'
    'A1UEAxMHUm9vdCBZRTB2MBAGByqGSM49AgEGBSuBBAAiA2IABDwS/6vhrcVqcbBo\n'
    '+wgdI3fwn9x7DNJJOY/lTOti0vkwuRN87RhEhTH17E7XyFjWsPYhIPt/wzOqxTd2\n'
    'b+4ZJNy9ID04YywF9U5zasDVyGSNErVNtz8uSGh5izW87j77GaOB6zCB6DAOBgNV\n'
    'HQ8BAf8EBAMCAQYwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDwYDVR0TAQH/BAUwAwEB\n'
    '/zAdBgNVHQ4EFgQUo8gmWo6hTNA1Y/ybI8g6rlbzT1YwHwYDVR0jBBgwFoAUfEKW\n'
    'rt5LSDv6kviejM9ti6lyN5UwMgYIKwYBBQUHAQEEJjAkMCIGCCsGAQUFBzAChhZo\n'
    'dHRwOi8veDIuaS5sZW5jci5vcmcvMBMGA1UdIAQMMAowCAYGZ4EMAQIBMCcGA1Ud\n'
    'HwQgMB4wHKAaoBiGFmh0dHA6Ly94Mi5jLmxlbmNyLm9yZy8wCgYIKoZIzj0EAwMD\n'
    'aQAwZgIxAMU19WCtmxVND8UHBZRoma49Z7jPs64Dma0eTu1OChVbB/2J7GV3nvYK\n'
    'Ax54uk1G9QIxAO0miLVJu8PLNiXXXkiE/gsK3CTRTF/aeo4bMX42Zw40csRU6AC2\n'
    '6hSW1/IWaas6dg==\n';

  // ISRG Root X2 (second backup anchor).
  static const _rootX2Pem =
    'MIIEcDCCAligAwIBAgIQbI8dxyfHEX97r4U6yYD5zTANBgkqhkiG9w0BAQsFADBP\n'
    'MQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJuZXQgU2VjdXJpdHkgUmVzZWFy\n'
    'Y2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBYMTAeFw0yNjA1MTMwMDAwMDBa\n'
    'Fw0zMjA5MDIyMzU5NTlaME8xCzAJBgNVBAYTAlVTMSkwJwYDVQQKEyBJbnRlcm5l\n'
    'dCBTZWN1cml0eSBSZXNlYXJjaCBHcm91cDEVMBMGA1UEAxMMSVNSRyBSb290IFgy\n'
    'MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAEzZvVn4CDCuwJSvMWSj5cz3es3mcFDR0H\n'
    'ttwW+1qLFNvicWDEukWVEYmO6gbf9yoWHKS5xcUy4APgHoIYOIvXRdgKam7mAHf7\n'
    'AlF9ItgKbppbd9/w+kHsOdx1ymgHDB/qo4H1MIHyMA4GA1UdDwEB/wQEAwIBBjAd\n'
    'BgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDwYDVR0TAQH/BAUwAwEB/zAd\n'
    'BgNVHQ4EFgQUfEKWrt5LSDv6kviejM9ti6lyN5UwHwYDVR0jBBgwFoAUebRZ5nu2\n'
    '5eQBc4AIiMgaWPbpm24wMgYIKwYBBQUHAQEEJjAkMCIGCCsGAQUFBzAChhZodHRw\n'
    'Oi8veDEuaS5sZW5jci5vcmcvMBMGA1UdIAQMMAowCAYGZ4EMAQIBMCcGA1UdHwQg\n'
    'MB4wHKAaoBiGFmh0dHA6Ly94MS5jLmxlbmNyLm9yZy8wDQYJKoZIhvcNAQELBQAD\n'
    'ggIBAD2/e9frmMxNpCV03qUHegg+MV2wz9644YoXdqtH8RyWYcBO7xfjjGEXdU1e\n'
    '/o0OkEFiynUCOSIk/vLLo7ttz6CPAeNlWfC0XNkoGeWgK6jjXvozBaGuGH5n0Ufo\n'
    'shMeWTuURqNN5G00sSXDTBrpp2+mgvdZQjb8K11TYMA25QA+YHNfbIEL0BniAhKS\n'
    '2gsnJjSzrdZLI+EZ7SEyqdR2rkjd1KutLDU+n3TFyxjniZVGur4YlhMP3mY/dV95\n'
    'IruAkkjOZier6hGBdEgZXXvaCz9u9iVEadsIE75pAGL8oHV5vxdARDiotRpul1IN\n'
    '/UZwzAbrfUFcw1HkAcYD/mlZfnQ2ieCF2MS7j3Vhv7JPDKp45fmykmzYNSrumRW0\n'
    'upFFKDBOoF7hsOb7oLyHS+Uft6jOUfOrogj8YUx38hKb2K20r42OgsSdDdxdeYWc\n'
    'MS3Sb6mwJeSZEYxJ2gaXnDSPaKhhrNkYwljyVQyr4Nq+MEJytXNTnHqaAcrNwZlV\n'
    'pcJL1KBnMrMjP7eanvUwL3FYj3cF17jtboLt7gLoi4+2rWZFvn+w54jmd/FIuhhZ\n'
    'cEaU/wvU6BUNMtcVquVGHp7itQeDth5j+XL3j4WJ2SABwzUl6OeYdgpIt/ITZa+p\n'
    'TT0mQ/r5XyA4MEAiabn7XJjvCERlF2dcn2wqJw+CreTkkQ2R\n';

  static String _pem(String body) =>
      '-----BEGIN CERTIFICATE-----\n$body-----END CERTIFICATE-----\n';

  /// Builds an [HttpClient] whose trust store contains ONLY the pinned
  /// anchors above (no system roots). A chain that does not terminate
  /// at one of them fails the handshake — this is the pinning.
  static HttpClient createPinnedHttpClient() {
    final context = SecurityContext(withTrustedRoots: false);
    context.setTrustedCertificatesBytes(utf8.encode(_pem(_ye2Pem)));
    context.setTrustedCertificatesBytes(utf8.encode(_pem(_rootYePem)));
    context.setTrustedCertificatesBytes(utf8.encode(_pem(_rootX2Pem)));
    return HttpClient(context: context);
  }

  static http.Client? _client;

  /// Shared pinned client for all store API calls.
  static http.Client get client =>
      _client ??= IOClient(createPinnedHttpClient());
}
