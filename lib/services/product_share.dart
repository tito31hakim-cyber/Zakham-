import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';
import 'secure_http.dart';

/// مشاركة عطر: نص عربي (الاسم + السعر + رابط صفحة العطر) مع صورة
/// العطر الحقيقية من المتجر كملف مرفق. إن تعذّر تنزيل الصورة لأي
/// سبب، تُشارَك الرسالة النصية والرابط فقط — المشاركة لا تفشل أبداً
/// بسبب الصورة.
class ProductShare {
  ProductShare._();

  /// النص العربي المشترك (يُختبر وحدوياً).
  static String shareText(Product product) =>
      'اكتشف عطر ${product.name} من دار زخم — '
      '${product.price.toStringAsFixed(0)} ${product.currency} '
      '(${product.size}).\n${product.productUrl}';

  static Future<void> share(Product product) async {
    final text = shareText(product);
    final image = await _downloadImage(product.image);
    try {
      if (image != null) {
        final lower = product.image.toLowerCase();
        final isPng = lower.contains('.png');
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: product.name,
            files: <XFile>[
              XFile.fromData(
                image,
                name: 'zakham-${product.id}.${isPng ? 'png' : 'jpg'}',
                mimeType: isPng ? 'image/png' : 'image/jpeg',
              ),
            ],
          ),
        );
        return;
      }
    } catch (_) {
      // أي فشل في مشاركة الملف يسقط للنسخة النصية.
    }
    await SharePlus.instance.share(
      ShareParams(text: text, subject: product.name),
    );
  }

  static Future<Uint8List?> _downloadImage(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await SecureHttp.client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
