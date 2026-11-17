import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_headers.dart';
import 'secure_http.dart';

/// Thrown when the server says the customer session is missing or expired
/// (401). The caller clears the stored session and asks the customer to
/// sign in again.
class AuthRequiredException implements Exception {
  const AuthRequiredException([this.message = 'سجّل الدخول إلى حسابك أولاً.']);
  final String message;
  @override
  String toString() => message;
}

/// A store customer, as returned by `customerPayload` on the server
/// (openId, displayName, email, phone, phoneVerified, discountCode,
/// discountUsed, createdAt, status, tags, pointsBalance).
class Customer {
  const Customer({
    required this.openId,
    required this.displayName,
    required this.email,
    this.phone = '',
    this.phoneVerified = false,
    this.discountCode = '',
    this.status = 'active',
    this.pointsBalance,
  });

  final String openId;
  final String displayName;
  final String email;
  final String phone;
  final bool phoneVerified;
  final String discountCode;
  final String status;

  /// رصيد نقاط الولاء من الخادم (كل نقطة = جنيه خصم)، أو null عندما
  /// لا يعيد الخادم الحقل بعد (نقطة الولاء لم تُنشر) — null تعني
  /// «قريباً» لا صفراً.
  final int? pointsBalance;

  Customer copyWith({int? pointsBalance}) => Customer(
        openId: openId,
        displayName: displayName,
        email: email,
        phone: phone,
        phoneVerified: phoneVerified,
        discountCode: discountCode,
        status: status,
        pointsBalance: pointsBalance ?? this.pointsBalance,
      );

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        openId: '${json['openId'] ?? ''}',
        displayName: '${json['displayName'] ?? ''}',
        email: '${json['email'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        phoneVerified: json['phoneVerified'] == true,
        discountCode: '${json['discountCode'] ?? ''}',
        status: '${json['status'] ?? 'active'}',
        pointsBalance: json['pointsBalance'] is num
            ? (json['pointsBalance'] as num).toInt()
            : null,
      );
}

/// Result of register/login: either a signed-in customer, or a pending
/// phone verification (the server sends a 6-digit SMS code and answers
/// verificationRequired:true with the masked phone).
class AuthOutcome {
  const AuthOutcome({
    this.customer,
    this.verificationRequired = false,
    this.phoneMask = '',
    this.message = '',
  });

  final Customer? customer;
  final bool verificationRequired;
  final String phoneMask;
  final String message;
}

/// One order of the signed-in customer (GET /api/account/orders).
class CustomerOrder {
  const CustomerOrder({
    required this.orderRef,
    required this.createdAt,
    this.customerName = '',
    this.phone = '',
    this.governorate = '',
    this.address = '',
    this.paymentMethod = '',
    this.subtotal = 0,
    this.shippingFee = 0,
    this.total = 0,
    this.status = '',
    this.paymentStatus = '',
  });

  final String orderRef;
  final String createdAt;
  final String customerName;
  final String phone;
  final String governorate;
  final String address;
  final String paymentMethod;
  final double subtotal;
  final double shippingFee;
  final double total;
  final String status;

  /// حالة الدفع كما يردها الخادم ('verified' تعني مدفوعاً)، أو ''
  /// عندما لا يرسلها الرد بعد (قائمة الطلبات القديمة) — يُملأ حينها
  /// من تفاصيل الفاتورة (GET /api/orders/{ref}/invoice) بهدوء.
  final String paymentStatus;

  factory CustomerOrder.fromJson(Map<String, dynamic> json) => CustomerOrder(
        orderRef: '${json['orderRef'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
        customerName: '${json['customerName'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        governorate: '${json['governorate'] ?? ''}',
        address: '${json['address'] ?? ''}',
        paymentMethod: '${json['paymentMethod'] ?? ''}',
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        shippingFee: (json['shippingFee'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        status: '${json['status'] ?? ''}',
        paymentStatus: '${json['paymentStatus'] ?? ''}',
      );

  CustomerOrder copyWith({String? paymentStatus}) => CustomerOrder(
        orderRef: orderRef,
        createdAt: createdAt,
        customerName: customerName,
        phone: phone,
        governorate: governorate,
        address: address,
        paymentMethod: paymentMethod,
        subtotal: subtotal,
        shippingFee: shippingFee,
        total: total,
        status: status,
        paymentStatus: paymentStatus ?? this.paymentStatus,
      );
}

/// Customer auth client for the real store backend.
///
/// The PHP backend authenticates customers with PHP sessions, exactly like
/// the web storefront: POST /api/auth/register and /api/auth/login set the
/// session (and the long-lived `zk_remember` cookie), GET /api/auth/me
/// validates it, and POST /api/orders requires it (401
/// login_required_for_checkout otherwise). The `package:http` client does
/// not manage cookies, so this class captures `Set-Cookie` from auth
/// responses and sends the cookies back as a `Cookie` header — the same
/// plumbing AdminApi uses for admin sessions.
///
/// Only the cookie string is persisted (by the provider, in encrypted
/// secure storage). Passwords are never stored or logged.
class CustomerAuth {
  CustomerAuth({this.baseUrl = AppConfig.apiBaseUrl});

  final String baseUrl;

  /// name -> value jar, kept so PHPSESSID and zk_remember survive together.
  final Map<String, String> _cookies = {};

  String? _cookie;
  String? get cookie => _cookie;
  bool get hasCookie => _cookie != null && _cookie!.isNotEmpty;

  ApiCredentials get credentials => ApiCredentials(cookie: _cookie);

  Map<String, String> _headers({bool mutating = false}) => ApiHeaders.build(
        credentials: ApiCredentials(cookie: _cookie),
        json: mutating,
        mutating: mutating,
      );

  Uri _url(String path) => Uri.parse('$baseUrl$path');

  /// Restores a previously persisted `Cookie` header value.
  void restoreCookie(String? header) {
    if (header == null || header.trim().isEmpty) return;
    for (final part in header.split(';')) {
      final first = part.trim();
      final eq = first.indexOf('=');
      if (eq <= 0) continue;
      final value = first.substring(eq + 1).trim();
      if (value.isNotEmpty) _cookies[first.substring(0, eq).trim()] = value;
    }
    _syncCookieHeader();
  }

  void clearCookie() {
    _cookies.clear();
    _cookie = null;
  }

  /// Keeps every cookie from a response. Several `Set-Cookie` headers
  /// arrive joined with ", " — the split only breaks on a comma that
  /// starts a new `name=value` cookie, never on the commas inside
  /// `Expires=Thu, 18 Nov ...` dates.
  void _captureCookies(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final parts =
        raw.split(RegExp(r",\s*(?=[A-Za-z0-9_!#$%&'*+\-.^`|~]+=)"));
    for (final part in parts) {
      final first = part.split(';').first.trim();
      final eq = first.indexOf('=');
      if (eq <= 0) continue;
      final name = first.substring(0, eq).trim();
      final value = first.substring(eq + 1).trim();
      if (value.isEmpty) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
    _syncCookieHeader();
  }

  void _syncCookieHeader() {
    _cookie = _cookies.isEmpty
        ? null
        : _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  AuthOutcome _outcome(Map<String, dynamic> data) {
    final raw = data['customer'];
    return AuthOutcome(
      customer: raw is Map<String, dynamic> ? Customer.fromJson(raw) : null,
      verificationRequired: data['verificationRequired'] == true,
      phoneMask: '${data['phoneMask'] ?? ''}',
      message: '${data['message'] ?? ''}',
    );
  }

  Future<AuthOutcome> register({
    required String displayName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final data = await _post(_url(AppConfig.customerRegisterPath), {
      'displayName': displayName.trim(),
      'email': email.trim(),
      'password': password,
      'phone': phone.trim(),
    });
    return _outcome(data);
  }

  Future<AuthOutcome> login({
    required String email,
    required String password,
  }) async {
    final data = await _post(_url(AppConfig.customerLoginPath), {
      'email': email.trim(),
      'password': password,
    });
    return _outcome(data);
  }

  /// Confirms the 6-digit SMS code. The session cookie from register/login
  /// (pending customer) must be sent — the server resolves the account
  /// from it. Returns the decoded body ({ok, verified, phoneMask}).
  Future<Map<String, dynamic>> verifyPhone(String code) =>
      _post(_url(AppConfig.customerVerifyPhonePath), {
        'code': code.trim(),
      });

  Future<Map<String, dynamic>> resendPhone(String phone) =>
      _post(_url(AppConfig.customerResendPhonePath), {
        'phone': phone.trim(),
      });

  /// Returns the signed-in customer, or null when there is no session.
  Future<Customer?> fetchMe() async {
    final data = await _get(_url(AppConfig.customerMePath));
    if (data['authenticated'] != true) return null;
    final raw = data['customer'];
    if (raw is Map<String, dynamic>) return Customer.fromJson(raw);
    return null;
  }

  /// رصيد نقاط الولاء من الخادم (GET /api/account/points)، أو null عند
  /// غياب النقطة (404 — الخادم لم يُنشر بعد) أو أي فشل آخر. best-effort
  /// ولا يرمي أبداً؛ غيابه يعني «قريباً» لا صفراً، وجلسة منتهية تُكتشف
  /// من /api/auth/me لا من هنا.
  Future<int?> fetchPointsBalance() async {
    try {
      final data = await _get(_url(AppConfig.customerPointsPath));
      final value = data['pointsBalance'];
      if (value is num) return value.toInt();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// العناوين المحفوظة (GET /api/account/addresses) — تُرمى عند غياب
  /// النقطة (404) أو أي فشل، فيسقط المتصل للتخزين المحلي بهدوء.
  Future<List<Map<String, dynamic>>> fetchAddresses() async {
    final data = await _get(_url(AppConfig.customerAddressesPath));
    final list = data['addresses'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createAddress(
    Map<String, dynamic> body,
  ) async {
    final data = await _post(_url(AppConfig.customerAddressesPath), body);
    final raw = data['address'];
    if (raw is Map<String, dynamic>) return raw;
    throw Exception('تعذر حفظ العنوان.');
  }

  Future<Map<String, dynamic>> updateAddress(
    String id,
    Map<String, dynamic> body,
  ) async {
    final uri =
        _url('${AppConfig.customerAddressesPath}/${Uri.encodeComponent(id)}');
    final response = await SecureHttp.client
        .patch(uri, headers: _headers(mutating: true), body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    _captureCookies(response);
    final data = _validate(response);
    final raw = data['address'];
    if (raw is Map<String, dynamic>) return raw;
    throw Exception('تعذر تحديث العنوان.');
  }

  Future<void> deleteAddress(String id) async {
    final uri = _url('${AppConfig.customerAddressesPath}/${Uri.encodeComponent(id)}');
    final response = await SecureHttp.client
        .delete(uri, headers: _headers(mutating: true))
        .timeout(const Duration(seconds: 20));
    _captureCookies(response);
    _validate(response);
  }

  /// تفاصيل طلب واحد مع أصنافه وحالة الدفع (GET /api/orders/{ref}/invoice).
  /// النقطة موجودة على الخادم الحي؛ صاحب الطلب المُسجَّل مخوَّل بها
  /// بجلسة العميل. تُرمى عند أي فشل فيُظهر المتصل رسالة الخادم.
  Future<Map<String, dynamic>> fetchOrderInvoice(String ref) async {
    final data = await _get(AppConfig.orderInvoiceUri(ref));
    final raw = data['order'];
    if (raw is Map<String, dynamic>) return raw;
    throw Exception('تعذر تحميل تفاصيل الطلب.');
  }

  Future<List<CustomerOrder>> fetchMyOrders() async {
    final data = await _get(_url(AppConfig.customerOrdersPath));
    final list = data['orders'];
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .map(CustomerOrder.fromJson)
          .toList(growable: false);
    }
    return const <CustomerOrder>[];
  }

  Future<void> logout() async {
    try {
      await _post(_url(AppConfig.customerLogoutPath), <String, dynamic>{});
    } catch (_) {
      // The session is dropped locally either way.
    } finally {
      clearCookie();
    }
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await SecureHttp.client
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 20));
    _captureCookies(response);
    return _validate(response);
  }

  Future<Map<String, dynamic>> _post(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await SecureHttp.client
        .post(
          uri,
          headers: _headers(mutating: true),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    _captureCookies(response);
    return _validate(response);
  }

  Map<String, dynamic> _validate(http.Response response) {
    final body = _decode(response.body);
    if (response.statusCode == 401) {
      throw AuthRequiredException(
        (body['message'] as String?)?.trim().isNotEmpty == true
            ? body['message'] as String
            : 'سجّل الدخول إلى حسابك أولاً.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (body['message'] as String?)?.trim().isNotEmpty == true
            ? body['message']
            : 'تعذر تنفيذ الطلب.',
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
