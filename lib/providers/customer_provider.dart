import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/address_book.dart';
import '../services/api_headers.dart';
import '../services/birthday.dart';
import '../services/birthday_service.dart';
import '../services/consultation.dart';
import '../services/customer_auth.dart';
import '../services/invoice_pdf.dart';
import '../services/reminder_service.dart';

/// Holds the signed-in store customer for the whole app.
///
/// The session is the PHP session cookie (+ the long-lived `zk_remember`
/// cookie) issued by /api/auth/register and /api/auth/login. The cookie
/// string is persisted in encrypted secure storage (Android Keystore /
/// iOS Keychain via flutter_secure_storage) so sign-in survives restarts;
/// it is validated on startup with GET /api/auth/me and cleared on
/// logout or on a 401 from the server. Passwords are never stored.
///
/// Legacy sessions saved in plain SharedPreferences (app <= 1.1.0) are
/// migrated once on first launch: the old value is read, moved to secure
/// storage and deleted from SharedPreferences.
class CustomerProvider extends ChangeNotifier {
  CustomerProvider({CustomerAuth? auth}) : _auth = auth ?? CustomerAuth();

  final CustomerAuth _auth;

  static const _cookieKey = 'zakham_customer_cookie';

  /// Encrypted on-device storage (Keystore / Keychain). Never put the
  /// session cookie in plain SharedPreferences again.
  static const _storage = FlutterSecureStorage();

  Customer? _customer;
  Customer? get customer => _customer;
  bool get isAuthenticated => _customer != null;
  bool get phoneVerified => _customer?.phoneVerified ?? false;

  /// Set while a phone verification is pending (register/login answered
  /// verificationRequired:true). The OTP page shows [pendingPhoneMask]
  /// and resends to [pendingPhone].
  bool _verificationPending = false;
  bool get verificationPending => _verificationPending;
  String _pendingPhoneMask = '';
  String get pendingPhoneMask => _pendingPhoneMask;
  String _pendingPhone = '';
  String get pendingPhone => _pendingPhone;

  bool _initializing = true;
  bool get initializing => _initializing;

  bool _busy = false;
  bool get busy => _busy;

  List<CustomerOrder> _orders = const [];
  List<CustomerOrder> get orders => _orders;

  ApiCredentials get credentials => _auth.credentials;

  /// دفتر العناوين المحفوظة — يشارك جلسة العميل نفسها (نفس
  /// CustomerAuth) فتصل نقاط `/api/account/addresses` بالكوكيز.
  late final AddressBookService addressBook = AddressBookService(_auth);

  /// تاريخ الميلاد — يشارك جلسة العميل نفسها (نقطة
  /// `/api/account/birthday`)، ويسقط للمحلي عند غيابها.
  late final BirthdayService birthdayService = BirthdayService(_auth);

  /// طلبات الاستشارة العطرية — محلية فقط (بلا خادم).
  late final ConsultationService consultations = ConsultationService();

  /// مفتاح التخزين المحلي للعناوين — يفصل عناوين حساب عن آخر على
  /// الجهاز نفسه (الضيف يستخدم 'guest').
  String get addressOwnerKey {
    final openId = _customer?.openId ?? '';
    if (openId.isNotEmpty) return openId;
    final email = _customer?.email ?? '';
    return email.isNotEmpty ? email : 'guest';
  }

  /// رصيد نقاط الولاء كما جاء من الخادم، أو null إن لم يدعمه بعد.
  int? get pointsBalance => _customer?.pointsBalance;

  /// تاريخ ميلاد العميل (من الخادم عند توفره، وإلا محلي) — null إن
  /// لم يُسجَّل بعد. ثابت بعد تسجيله.
  DateTime? get birthday => _customer?.birthdayDate;

  /// يحدّث رصيد النقاط من الخادم (best-effort): غياب النقطة يعني أن
  /// الخادم لم يُنشر بعد فيبقى الرصيد كما هو (أو null = «قريباً»).
  /// لا يرمي أبداً فلا يعطّل أي شاشة.
  Future<void> refreshPoints() async {
    if (_customer == null) return;
    try {
      final balance = await _auth.fetchPointsBalance();
      if (balance != null) {
        _customer = _customer!.copyWith(pointsBalance: balance);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// يحدّث تاريخ الميلاد (الخادم أولاً ثم المحلي) ويجدول إشعار
  /// الهدية قبل عيد الميلاد بـ 3 أيام. best-effort ولا يرمي أبداً.
  Future<void> refreshBirthday() async {
    if (_customer == null) return;
    try {
      final birthday = await birthdayService.load(
        ownerKey: addressOwnerKey,
      );
      if (birthday != null) {
        _customer = _customer!.copyWith(birthday: formatBirthday(birthday));
        notifyListeners();
        await ReminderService.instance.ensureBirthdayReminder(
          birthday: birthday,
        );
      }
    } catch (_) {}
  }

  /// Restores the persisted session cookie and validates it with /me.
  /// Never throws — a dead session just means "signed out".
  Future<void> init() async {
    try {
      var cookie = await _storage.read(key: _cookieKey);
      cookie ??= await _migrateLegacyCookie();
      _auth.restoreCookie(cookie);
      if (_auth.hasCookie) {
        _customer = await _auth.fetchMe();
        if (_customer == null) _auth.clearCookie();
      }
      if (_customer != null) unawaited(refreshBirthday());
    } catch (_) {
      _customer = null;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  /// One-time migration of a session saved by app <= 1.1.0 in plain
  /// SharedPreferences: move it to secure storage and delete the old key.
  Future<String?> _migrateLegacyCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_cookieKey);
      if (legacy == null || legacy.isEmpty) return null;
      await _storage.write(key: _cookieKey, value: legacy);
      await prefs.remove(_cookieKey);
      return legacy;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistCookie() async {
    try {
      final cookie = _auth.cookie;
      if (cookie == null || cookie.isEmpty) {
        await _storage.delete(key: _cookieKey);
      } else {
        await _storage.write(key: _cookieKey, value: cookie);
      }
    } catch (_) {
      // Secure storage can fail on a device without a working Keystore /
      // Keychain; the session still works in memory for this run — it
      // just won't survive a restart. Never fail sign-in over storage.
    }
  }

  void _applyOutcome(AuthOutcome outcome, {required String phone}) {
    _customer = outcome.customer;
    if (outcome.verificationRequired) {
      _verificationPending = true;
      _pendingPhoneMask = outcome.phoneMask;
      _pendingPhone = phone;
    } else {
      _verificationPending = false;
      _pendingPhoneMask = '';
      _pendingPhone = '';
    }
  }

  Future<AuthOutcome> register({
    required String displayName,
    required String email,
    required String password,
    required String phone,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final outcome = await _auth.register(
        displayName: displayName,
        email: email,
        password: password,
        phone: phone,
      );
      _applyOutcome(outcome, phone: phone);
      await _persistCookie();
      return outcome;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<AuthOutcome> login({
    required String email,
    required String password,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final outcome = await _auth.login(email: email, password: password);
      // The login form has no phone field; the pending phone comes from
      // the account itself (masked), resend uses the stored phone.
      _applyOutcome(outcome, phone: _customer?.phone ?? '');
      await _persistCookie();
      return outcome;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Confirms the 6-digit SMS code, then refreshes the profile so the
  /// verified flag is current. Returns true on success.
  Future<bool> verifyPhone(String code) async {
    final data = await _auth.verifyPhone(code);
    if (data['verified'] == true) {
      _verificationPending = false;
      _pendingPhoneMask = '';
      _pendingPhone = '';
      await _persistCookie();
      try {
        _customer = await _auth.fetchMe() ?? _customer;
      } catch (_) {
        // Profile refresh is best-effort; verification already succeeded.
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> resendPhone() =>
      _auth.resendPhone(_pendingPhone);

  /// Starts phone verification for a signed-in but unverified customer
  /// (possible in relaxed/bypass OTP modes): sends a fresh SMS code and
  /// marks verification pending so the OTP page can confirm it.
  Future<void> beginPhoneVerification() async {
    final phone = _customer?.phone ?? '';
    if (phone.isEmpty) {
      throw Exception('لا يوجد رقم هاتف على هذا الحساب.');
    }
    _verificationPending = true;
    _pendingPhone = phone;
    _pendingPhoneMask = _maskPhone(phone);
    notifyListeners();
    await _auth.resendPhone(phone);
  }

  String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    return '••••••${digits.substring(digits.length - 4)}';
  }

  Future<void> refreshOrders() async {
    try {
      _orders = await _auth.fetchMyOrders();
    } on AuthRequiredException {
      await _dropLocalSession();
      rethrow;
    } finally {
      notifyListeners();
    }
    // حالة الدفع قد لا تأتي مع قائمة الطلبات بعد (خادم قديم) — تُملأ
    // بهدوء من تفاصيل الفاتورة لكل طلب غير ملغى ولا يحمل حالة، ليعرض
    // زر «تنزيل الفاتورة PDF» فقط للمدفوعة. أي فشل يُتجاهل ولا يعطّل
    // قائمة الطلبات.
    await _backfillPaymentStatus();
  }

  Future<void> _backfillPaymentStatus() async {
    var changed = false;
    final updated = <CustomerOrder>[];
    for (final order in _orders) {
      if (order.paymentStatus.isNotEmpty || order.status == 'cancelled') {
        updated.add(order);
        continue;
      }
      try {
        final invoice = await _auth.fetchOrderInvoice(order.orderRef);
        final paymentStatus = '${invoice['paymentStatus'] ?? ''}';
        if (paymentStatus.isNotEmpty) {
          updated.add(order.copyWith(paymentStatus: paymentStatus));
          changed = true;
        } else {
          updated.add(order);
        }
      } catch (_) {
        updated.add(order);
      }
    }
    if (changed) {
      _orders = updated;
      notifyListeners();
    }
  }

  /// تفاصيل طلب واحد كفاتورة (GET /api/orders/{ref}/invoice) —
  /// null عند أي فشل. تُستخدم لزر «تنزيل الفاتورة PDF» للطلبات المدفوعة.
  Future<OrderInvoice?> fetchInvoice(String ref) async {
    try {
      final data = await _auth.fetchOrderInvoice(ref);
      return OrderInvoice.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    await _persistCookie();
    _customer = null;
    _orders = const [];
    _verificationPending = false;
    _pendingPhoneMask = '';
    _pendingPhone = '';
    notifyListeners();
  }

  /// تسجيل الخروج من كل الأجهزة (نقطة خادم جديدة — انظر
  /// [CustomerAuth.logoutFromAllDevices]). عند النجاح تُنسى الجلسة
  /// محلياً كما في الخروج العادي؛ وعند عدم توفر النقطة بعد (404)
  /// يبقى العميل مسجَّلاً على هذا الجهاز وتُظهر الواجهة رسالة واضحة.
  Future<void> logoutFromAllDevices() async {
    await _auth.logoutFromAllDevices();
    await _persistCookie();
    _customer = null;
    _orders = const [];
    _verificationPending = false;
    _pendingPhoneMask = '';
    _pendingPhone = '';
    notifyListeners();
  }

  /// إعادة رفع إثبات دفع لطلب رُفض إثباته — يحدّث حالة الدفع في
  /// القائمة المحلية إلى ما أعاده الخادم ('proof_submitted') ويعيدها.
  Future<String> resubmitReceipt(
    String orderRef,
    List<int> bytes,
    String filename,
  ) async {
    final status = await _auth.resubmitReceipt(
      orderRef: orderRef,
      bytes: bytes,
      filename: filename,
    );
    _orders = _orders
        .map(
          (order) => order.orderRef == orderRef
              ? order.copyWith(paymentStatus: status)
              : order,
        )
        .toList(growable: false);
    notifyListeners();
    return status;
  }

  /// Called when an API call reports a dead session (e.g. checkout 401):
  /// forget the local session so the UI asks for sign-in again.
  Future<void> dropSession() => _dropLocalSession();

  Future<void> _dropLocalSession() async {
    _auth.clearCookie();
    await _persistCookie();
    _customer = null;
    _orders = const [];
    notifyListeners();
  }
}
