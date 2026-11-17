import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// يحلّل رابط متجر وارداً ويعيد معرّف العطر (slug) إن كان رابط منتج
/// `https://zakhamhouse.shop/product/<slug>`، وإلا null.
/// الـ slug هو نفسه `product_id` في رد `/api/storefront`
/// (layl، elixir، sultan، royal، storm، aura، aurora، fares،
/// tobacco، fahd، musk).
String? parseProductSlug(Uri uri) {
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  final host = uri.host.toLowerCase();
  if (host != 'zakhamhouse.shop' && host != 'www.zakhamhouse.shop') {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length != 2 || segments[0] != 'product') return null;
  final slug = segments[1].trim();
  if (slug.isEmpty) return null;
  if (!RegExp(r'^[a-z0-9][a-z0-9_-]*$').hasMatch(slug)) return null;
  return slug;
}

/// يستقبل الروابط العميقة (App Links) لنطاق المتجر ويمرّر معرّف العطر
/// إلى التطبيق: الرابط الافتتاحي عند التشغيل البارد + أي رابط يصل
/// والتطبيق مفتوح أو في الخلفية. كل خطوة best-effort: فشل قناة
/// المنصة (مثلاً في الاختبارات) يُتجاهل بهدوء.
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  Future<void> init({required ValueChanged<String> onProductSlug}) async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        final slug = parseProductSlug(initial);
        if (slug != null) onProductSlug(slug);
      }
    } catch (_) {
      // لا رابط افتتاحي أو القناة غير متاحة — يُتجاهل.
    }
    try {
      _subscription = _appLinks.uriLinkStream.listen(
        (uri) {
          final slug = parseProductSlug(uri);
          if (slug != null) onProductSlug(slug);
        },
        onError: (_) {},
      );
    } catch (_) {
      // الاستماع للروابط غير متاح — يُتجاهل.
    }
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
