import 'dart:convert';

import '../config/app_config.dart';
import 'secure_http.dart';

/// تقييم عميل معتمَد (approved=1) من `/api/reviews`.
class Review {
  const Review({
    required this.productId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.verified,
    required this.createdAt,
  });

  final String productId;
  final String customerName;
  final int rating;
  final String comment;
  final bool verified;
  final String createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'];
    return Review(
      productId: '${json['productId'] ?? json['product_id'] ?? ''}',
      customerName: '${json['customerName'] ?? json['customer_name'] ?? ''}',
      rating: rating is num
          ? rating.toInt()
          : int.tryParse('$rating') ?? 5,
      comment: '${json['comment'] ?? ''}',
      verified: json['verified'] == 1 ||
          json['verified'] == true ||
          json['verified'] == '1',
      createdAt: '${json['createdAt'] ?? json['created_at'] ?? ''}',
    );
  }
}

/// ملخص التقييمات لعطر واحد من `/api/reviews/summary`.
class ReviewSummary {
  const ReviewSummary({required this.count, required this.average});
  final int count;
  final double average;
}

/// نتيجة إرسال تقييم إلى `/api/reviews` (POST).
class ReviewSubmitResult {
  const ReviewSubmitResult({
    required this.ok,
    required this.message,
    required this.verified,
  });
  final bool ok;
  final String message;
  final bool verified;
}

/// واجهة التقييمات الموجودة في المتجر (`api.php` — «ZAKHAM reviews
/// core v1»):
/// - GET `/api/reviews?productId=<id>` → قائمة المعتمَدة فقط
///   `[{productId, customerName, rating, comment, verified, createdAt}]`.
/// - GET `/api/reviews/summary` → `{products: {<id>: {count, average}}}`.
/// - POST `/api/reviews` بجسم JSON
///   `{productId, orderCode?, customerName, rating, comment}` →
///   201 `{ok, verified, message}`؛ والتقييم يُحفظ `approved=0`
///   فيُنشر بعد اعتماد الإدارة. أخطاء 422: `review_product_required`،
///   `review_name_required` (الاسم حرفان على الأقل)، `review_text_short`
///   (التجربة 10 أحرف على الأقل).
class ReviewsApi {
  ReviewsApi({String? baseUrl}) : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final String _baseUrl;

  /// التقييمات المعتمَدة لعطر — قائمة فارغة عند أي عطل (best-effort).
  Future<List<Review>> fetchReviews(String productId) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/reviews?productId=${Uri.encodeQueryComponent(productId)}',
      );
      final response = await SecureHttp.client
          .get(uri, headers: <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <Review>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const <Review>[];
      return decoded
          .whereType<Map>()
          .map((item) => Review.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return const <Review>[];
    }
  }

  /// ملخص التقييمات لكل العطور — خريطة فارغة عند أي عطل.
  Future<Map<String, ReviewSummary>> fetchSummary() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/reviews/summary');
      final response = await SecureHttp.client
          .get(uri, headers: <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <String, ReviewSummary>{};
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const <String, ReviewSummary>{};
      final products = decoded['products'];
      if (products is! Map) return const <String, ReviewSummary>{};
      final result = <String, ReviewSummary>{};
      products.forEach((key, value) {
        if (value is Map) {
          final count = value['count'];
          final average = value['average'];
          result['$key'] = ReviewSummary(
            count: count is num
                ? count.toInt()
                : int.tryParse('$count') ?? 0,
            average: average is num
                ? average.toDouble()
                : double.tryParse('$average') ?? 0,
          );
        }
      });
      return result;
    } catch (_) {
      return const <String, ReviewSummary>{};
    }
  }

  /// يرسل تقييماً جديداً. `orderCode` اختياري — إن طابق طلباً حقيقياً
  /// لنفس العطر يُوسم التقييم «عميل موثّق». الرسالة الراجعة من
  /// الخادم نفسها تُعرض للمستخدم (تذكر أن النشر بعد الاعتماد).
  Future<ReviewSubmitResult> submitReview({
    required String productId,
    required String customerName,
    required int rating,
    required String comment,
    String orderCode = '',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/reviews');
      final response = await SecureHttp.client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'productId': productId,
              'orderCode': orderCode,
              'customerName': customerName,
              'rating': rating.clamp(1, 5),
              'comment': comment,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      final message = decoded is Map
          ? '${decoded['message'] ?? ''}'.trim()
          : '';
      if (response.statusCode == 201) {
        return ReviewSubmitResult(
          ok: true,
          message: message.isEmpty ? 'تم استلام تقييمك، وسيُراجع قبل النشر.' : message,
          verified: decoded is Map && decoded['verified'] == true,
        );
      }
      return ReviewSubmitResult(
        ok: false,
        message: message.isEmpty ? 'تعذر إرسال التقييم، حاول بعد قليل.' : message,
        verified: false,
      );
    } catch (_) {
      return const ReviewSubmitResult(
        ok: false,
        message: 'تعذر إرسال التقييم، حاول بعد قليل.',
        verified: false,
      );
    }
  }
}
