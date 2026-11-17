import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// وضع الواجهة (داكنة/فاتحة) — يُحفظ في SharedPreferences (تفضيل
/// غير حساس، لا جلسة فيه) ويُطبَّق على التطبيق كله عبر `themeMode`.
/// الافتراضي داكن، كما اعتاد مستخدمو الدار.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'zakham_theme_light';

  bool _isLight = false;

  bool get isLight => _isLight;

  ThemeMode get mode => _isLight ? ThemeMode.light : ThemeMode.dark;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLight = prefs.getBool(_key) ?? false;
  }

  Future<void> setLight(bool value) async {
    if (_isLight == value) return;
    _isLight = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  Future<void> toggle() => setLight(!_isLight);
}
