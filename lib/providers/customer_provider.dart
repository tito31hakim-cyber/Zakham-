import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_headers.dart';
import '../services/customer_auth.dart';

/// Holds the signed-in store customer for the whole app.
///
/// The session is the PHP session cookie (+ the long-lived `zk_remember`
/// cookie) issued by /api/auth/register and /api/auth/login. The cookie
/// string is persisted in SharedPreferences so sign-in survives restarts;
/// it is validated on startup with GET /api/auth/me and cleared on
/// logout or on a 401 from the server. Passwords are never stored.
class CustomerProvider extends ChangeNotifier {
  CustomerProvider({CustomerAuth? auth}) : _auth = auth ?? CustomerAuth();

  final CustomerAuth _auth;

  static const _cookieKey = 'zakham_customer_cookie';

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

  /// Restores the persisted session cookie and validates it with /me.
  /// Never throws — a dead session just means "signed out".
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _auth.restoreCookie(prefs.getString(_cookieKey));
      if (_auth.hasCookie) {
        _customer = await _auth.fetchMe();
        if (_customer == null) _auth.clearCookie();
      }
    } catch (_) {
      _customer = null;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> _persistCookie() async {
    final prefs = await SharedPreferences.getInstance();
    final cookie = _auth.cookie;
    if (cookie == null || cookie.isEmpty) {
      await prefs.remove(_cookieKey);
    } else {
      await prefs.setString(_cookieKey, cookie);
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
