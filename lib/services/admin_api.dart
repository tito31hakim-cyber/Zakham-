import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'advisor_chat_api.dart';
import 'api_headers.dart';
import 'research_pdfs_api.dart';
import 'research_sync_api.dart';
import 'secure_http.dart';

/// Thrown when the server requires a two-factor (TOTP) code for this admin
/// account. The code comes from the admin's authenticator app; the web
/// page /zk-2fa.php handles enrolment, the app only submits the code.
class TotpRequiredException implements Exception {
  const TotpRequiredException();
  @override
  String toString() =>
      'هذا الحساب محمي برمز تحقق ثنائي — أدخل الرمز من تطبيق المصادقة.';
}

/// Admin client for the real store backend.
///
/// The PHP backend (api.php) authenticates admins with PHP sessions, not
/// bearer tokens (verified live 2026-11-17: GET /api/admin/session returns
/// a login CSRF token, POST /api/admin/login sets the session):
///   1. GET /api/admin/session  -> session cookie + loginCsrfToken.
///   2. POST /api/admin/login {email, password, totp?} with
///      `X-CSRF-Token: <loginCsrfToken>` and the session cookie
///      -> {ok, csrfToken, user}.
///   3. Every later call sends the session cookie; mutating calls also
///      send `X-CSRF-Token: <csrfToken>`.
/// The cookie and tokens live in memory only and are dropped on logout.
/// Never persist them in SharedPreferences or logs.
class AdminApi {
  AdminApi({this.baseUrl = AppConfig.apiBaseUrl, http.Client? client})
      : _client = client;

  final String baseUrl;

  /// HTTP client override — للاختبارات فقط. في الإنتاج يبقى null فيُستخدم
  /// عميل SecureHttp المثبّت الشهادة. لا يُمرَّر عميل حقيقي غير مثبّت أبداً.
  final http.Client? _client;

  http.Client get _http => _client ?? SecureHttp.client;

  /// عميل قراءة «بحث وابتكار» فوق جلسة الإدارة الحالية: كوكي الجلسة
  /// ورمز CSRF من الذاكرة فقط، وعلى عميل SecureHttp المثبّت نفسه.
  /// قراءة فقط، وبلا أي مفتاح خدمة — مفتاح الخدمة لا يصل إلى التطبيق أبداً.
  ResearchSyncApi get researchSyncApi => ResearchSyncApi(
        credentials: ApiCredentials(
          cookie: _cookie,
          csrfToken: _csrfToken,
        ),
        client: _http,
      );

  /// عميل محادثة المستشار فوق جلسة الإدارة الحالية: كوكي الجلسة
  /// ورمز CSRF من الذاكرة فقط، وعلى عميل SecureHttp المثبّت نفسه.
  /// وسيط خادم فقط بلا مفتاح إطلاقاً — المفتاح لا يصل إلى التطبيق أبداً.
  AdvisorChatApi get advisorChatApi => AdvisorChatApi(
        credentials: ApiCredentials(
          cookie: _cookie,
          csrfToken: _csrfToken,
        ),
        client: _http,
      );

  /// عميل رفع ملفات PDF لذاكرة البحث فوق جلسة الإدارة الحالية:
  /// كوكي الجلسة ورمز CSRF من الذاكرة فقط، وعلى عميل SecureHttp
  /// المثبّت نفسه. الملفات لا تدخل المعرفة إلا بعد مراجعة بشرية.
  ResearchPdfsApi get researchPdfsApi => ResearchPdfsApi(
        credentials: ApiCredentials(
          cookie: _cookie,
          csrfToken: _csrfToken,
        ),
        client: _http,
      );

  String? _cookie;
  String? _csrfToken;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _user != null;
  Map<String, dynamic>? get user => _user;
  String get displayName =>
      (_user?['displayName'] as String?)?.trim().isNotEmpty == true
          ? _user!['displayName'] as String
          : (_user?['email'] as String? ?? '');

  Map<String, String> _headers({bool mutating = false, String? csrf}) =>
      ApiHeaders.build(
        credentials: ApiCredentials(
          cookie: _cookie,
          csrfToken: csrf ?? (mutating ? _csrfToken : null),
        ),
        json: mutating,
        mutating: mutating,
      );

  Uri _url(String path) => Uri.parse('$baseUrl$path');

  /// Keeps the session cookie from a response (`Set-Cookie: PHPSESSID=...`).
  void _captureCookie(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    // A response may carry several cookies; the session cookie is the one
    // whose name starts with PHPSESSID (PHP default). Fall back to the
    // first cookie segment when the name is unknown.
    var sessionPart = '';
    for (final part in raw.split(',')) {
      final first = part.split(';').first.trim();
      if (first.startsWith('PHPSESSID=')) {
        sessionPart = first;
        break;
      }
      if (sessionPart.isEmpty) sessionPart = first;
    }
    if (sessionPart.isNotEmpty) _cookie = sessionPart;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 20));
    _captureCookie(response);
    return _validate(response);
  }

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, dynamic> body, {
    String? csrf,
  }) async {
    final response = await _http
        .post(
          uri,
          headers: _headers(mutating: true, csrf: csrf),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    _captureCookie(response);
    return _validate(response);
  }

  Future<Map<String, dynamic>> _patch(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await _http
        .patch(uri, headers: _headers(mutating: true), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    _captureCookie(response);
    return _validate(response);
  }

  Future<void> _delete(Uri uri) async {
    final response = await _http
        .delete(uri, headers: _headers(mutating: true))
        .timeout(const Duration(seconds: 20));
    _captureCookie(response);
    _validate(response);
  }

  /// Reads the current admin session (also warms the session cookie and
  /// returns the pre-login CSRF token when logged out).
  Future<Map<String, dynamic>> fetchSession() =>
      _get(_url(AppConfig.adminSessionPath));

  /// Logs in with the admin's real email and password.
  ///
  /// Throws [TotpRequiredException] when the account enforces two-factor
  /// authentication — call again with the authenticator code in [totp].
  Future<void> login({
    required String email,
    required String password,
    String? totp,
  }) async {
    final session = await fetchSession();
    final loginCsrf = (session['loginCsrfToken'] as String?)?.trim() ?? '';
    final uri = _url(AppConfig.adminLoginPath);
    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
    };
    final code = totp?.trim() ?? '';
    if (code.isNotEmpty) body['totp'] = code;
    final response = await _http
        .post(
          uri,
          headers: _headers(mutating: true, csrf: loginCsrf),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    _captureCookie(response);
    final data = _decode(response.body);
    if (response.statusCode == 401 &&
        (data['code'] == 'admin_totp_required' ||
            (data['message'] as String? ?? '').contains('تحقق ثنائي'))) {
      throw const TotpRequiredException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (data['message'] as String?)?.trim().isNotEmpty == true
            ? data['message']
            : 'البريد أو كلمة المرور غير صحيحة.',
      );
    }
    _csrfToken = (data['csrfToken'] as String?)?.trim();
    final user = data['user'];
    _user = user is Map<String, dynamic>
        ? user
        : <String, dynamic>{'email': email.trim()};
  }

  /// Ends the server session and forgets every credential in memory.
  Future<void> logout() async {
    try {
      await _post(_url(AppConfig.adminLogoutPath), <String, dynamic>{});
    } catch (_) {
      // The session is dropped locally either way.
    } finally {
      _cookie = null;
      _csrfToken = null;
      _user = null;
    }
  }

  Future<List<dynamic>> products() async =>
      (await _get(_url(AppConfig.adminProductsPath)))['products']
          as List<dynamic>? ??
      [];

  Future<List<dynamic>> customers([String query = '']) async =>
      (await _get(
        Uri.parse(
          '$baseUrl${AppConfig.adminCustomersPath}?q=${Uri.encodeQueryComponent(query)}',
        ),
      ))['customers'] as List<dynamic>? ??
      [];

  Future<Map<String, dynamic>> analytics() =>
      _get(_url(AppConfig.analyticsPath));

  /// Searches admin orders. [status] is a server status value
  /// (pending_transfer, paid, processing, shipped, delivered, cancelled)
  /// or '' for every status. The extra filters map 1:1 to what the
  /// server's adminOrdersList accepts (governorate LIKE, exact payment
  /// method / payment status, dateFrom/dateTo as YYYY-MM-DD); empty
  /// values are omitted so the call behaves exactly like before.
  /// Returns the raw page: orders, total, page,
  /// totalPages and bucketCounts.
  Future<Map<String, dynamic>> orders({
    String status = '',
    String governorate = '',
    String paymentMethod = '',
    String paymentStatus = '',
    String dateFrom = '',
    String dateTo = '',
    int page = 1,
  }) async {
    final body = <String, dynamic>{
      'page': page,
      'pageSize': 25,
      'sort': 'created_desc',
    };
    if (status.trim().isNotEmpty) body['status'] = status.trim();
    if (governorate.trim().isNotEmpty) {
      body['governorate'] = governorate.trim();
    }
    if (paymentMethod.trim().isNotEmpty) {
      body['paymentMethod'] = paymentMethod.trim();
    }
    if (paymentStatus.trim().isNotEmpty) {
      body['paymentStatus'] = paymentStatus.trim();
    }
    if (dateFrom.trim().isNotEmpty) body['dateFrom'] = dateFrom.trim();
    if (dateTo.trim().isNotEmpty) body['dateTo'] = dateTo.trim();
    return _post(_url(AppConfig.adminOrdersSearchPath), body);
  }

  /// Full admin order: customer data, items, receipts and history.
  Future<Map<String, dynamic>> orderDetail(String ref) async =>
      _get(_url('/api/admin/orders/${Uri.encodeComponent(ref)}'));

  /// Moves an order to [status] following the server transition rules.
  /// [reason] is required when cancelling.
  Future<Map<String, dynamic>> updateOrderStatus(
    String ref,
    String status, {
    String reason = '',
  }) async {
    final body = <String, dynamic>{'status': status};
    if (reason.trim().isNotEmpty) body['reason'] = reason.trim();
    return _patch(
      _url('/api/orders/${Uri.encodeComponent(ref)}/status'),
      body,
    );
  }

  /// Reviews a payment: verified / rejected / refunded.
  /// Set [manualConfirmation] with a clear [reason] to verify a payment
  /// that has no uploaded receipt.
  Future<Map<String, dynamic>> updatePaymentStatus(
    String ref,
    String paymentStatus, {
    String reason = '',
    bool manualConfirmation = false,
  }) async {
    final body = <String, dynamic>{'paymentStatus': paymentStatus};
    if (reason.trim().isNotEmpty) body['reason'] = reason.trim();
    if (manualConfirmation) body['manualConfirmation'] = true;
    return _patch(
      _url('/api/orders/${Uri.encodeComponent(ref)}/payment'),
      body,
    );
  }

  Future<void> updateProduct({
    required String id,
    required Map<String, dynamic> product,
  }) async {
    await _patch(
      _url('${AppConfig.adminProductsPath}/${Uri.encodeComponent(id)}'),
      product,
    );
  }

  /// Sends a push notification to one FCM topic via the store server
  /// (POST /api/admin/push/send). The endpoint is deployed on the server
  /// separately; until then the server answers 404 and this throws a
  /// clear message instead of a generic failure.
  Future<Map<String, dynamic>> sendPush({
    required String title,
    required String body,
    required String topic,
  }) async {
    final uri = _url(AppConfig.adminPushSendPath);
    final response = await _http
        .post(
          uri,
          headers: _headers(mutating: true),
          body: jsonEncode({
            'title': title.trim(),
            'body': body.trim(),
            'topic': topic.trim(),
          }),
        )
        .timeout(const Duration(seconds: 20));
    _captureCookie(response);
    final data = _decode(response.body);
    if (response.statusCode == 404) {
      throw Exception(
        'نقطة إرسال الإشعارات غير منشورة على الخادم بعد (404) — فعّلها من المتجر أولاً.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (data['message'] as String?)?.trim().isNotEmpty == true
            ? data['message']
            : 'تعذر إرسال الإشعار.',
      );
    }
    return data;
  }

  Future<void> deleteProduct(String id) async {
    await _delete(
      _url('${AppConfig.adminProductsPath}/${Uri.encodeComponent(id)}'),
    );
  }

  /// قواعد خصم «اشترِ 2» (GET/POST/PATCH/DELETE /api/admin/discounts
  /// بصلاحية offers.manage). النقطة مسودة على الخادم بعد — 404 تعني
  /// «غير منشورة بعد» وتُظهر رسالة صريحة بدل فشل عام.
  Future<List<Map<String, dynamic>>> discountRules() async {
    final data = await _get(_url(AppConfig.adminDiscountsPath));
    final list = data['rules'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createDiscountRule(
    Map<String, dynamic> body,
  ) async {
    final data = await _post(_url(AppConfig.adminDiscountsPath), body);
    final raw = data['rule'];
    if (raw is Map<String, dynamic>) return raw;
    throw Exception('تعذر إنشاء قاعدة الخصم.');
  }

  Future<Map<String, dynamic>> updateDiscountRule(
    String id,
    Map<String, dynamic> body,
  ) async {
    final data = await _patch(
      _url('${AppConfig.adminDiscountsPath}/${Uri.encodeComponent(id)}'),
      body,
    );
    final raw = data['rule'];
    if (raw is Map<String, dynamic>) return raw;
    throw Exception('تعذر تحديث قاعدة الخصم.');
  }

  Future<void> deleteDiscountRule(String id) async {
    await _delete(
      _url('${AppConfig.adminDiscountsPath}/${Uri.encodeComponent(id)}'),
    );
  }

  Map<String, dynamic> _validate(http.Response response) {
    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('انتهت جلسة الإدارة — سجّل الدخول مجدداً.');
      }
      throw Exception(
        (body['message'] as String?)?.trim().isNotEmpty == true
            ? body['message']
            : 'تعذر تنفيذ طلب الإدارة.',
      );
    }
    return body;
  }

  Map<String, dynamic> _decode(String raw) {
    if (raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : <String, dynamic>{};
    } catch (_) {
      throw Exception('الخادم أعاد استجابة غير صالحة.');
    }
  }
}
