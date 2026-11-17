import 'package:shared_preferences/shared_preferences.dart';

import 'birthday.dart';
import 'customer_auth.dart';

/// تاريخ ميلاد العميل — يُسجَّل مرة واحدة ولا يتغير أبداً.
///
/// القاعدة (من صاحب الدار): بعد الحفظ لا يمكن للعميل تغييره من
/// التطبيق إطلاقاً (التغيير فقط عن طريق الدار). تُفرض في التطبيق
/// (الحقل يصبح للقراءة فقط بعد أول حفظ) وفي الخادم (العمود
/// set-once — الخادم يرفض أي تحديث بعد تعيينه).
///
/// الحفظ: الخادم أولاً (POST /api/account/birthday) عند توفر نقطته،
/// وإلا محلياً؛ والقراءة: الخادم أولاً ثم المحلي بهدوء. غياب النقطة
/// (404 — الخادم لم يُنشر بعد) لا يكسر أي شاشة.
class BirthdayService {
  BirthdayService(this._auth);

  final CustomerAuth _auth;

  static const String _keyPrefix = 'zakham_birthday_v1_';

  /// يقرأ تاريخ الميلاد (الخادم أولاً، ثم المحلي)، أو null إن لم
  /// يُسجَّل بعد. لا يرمي أبداً.
  Future<DateTime?> load({required String ownerKey}) async {
    try {
      final server = await _auth.fetchBirthday();
      if (server != null) {
        await _saveLocal(ownerKey, server);
        return server;
      }
    } catch (_) {}
    return _loadLocal(ownerKey);
  }

  /// هل سُجِّل تاريخ الميلاد؟ (للقراءة السريعة من الواجهة).
  Future<bool> isSet({required String ownerKey}) async =>
      await load(ownerKey: ownerKey) != null;

  /// يحفظ تاريخ الميلاد مرة واحدة فقط. إن كان مسجَّلاً (محلياً أو
  /// على الخادم) يرمي Exception برسالة عربية دون كتابة أي شيء.
  /// يعيد التاريخ المحفوظ.
  Future<DateTime> save({
    required String ownerKey,
    required DateTime birthday,
  }) async {
    final existing = await load(ownerKey: ownerKey);
    if (existing != null) {
      throw Exception(
        'تاريخ الميلاد مسجَّل بالفعل ولا يمكن تغييره — للتغيير تواصل مع الدار.',
      );
    }
    try {
      final saved = await _auth.saveBirthday(formatBirthday(birthday));
      await _saveLocal(ownerKey, saved);
      return saved;
    } on BirthdayAlreadySetException {
      // الخادم يقول إنه مسجَّل (من جهاز آخر أو من المتجر) — نثبّت
      // المحلي بما يقوله الخادم ونرفض الكتابة.
      try {
        final server = await _auth.fetchBirthday();
        if (server != null) await _saveLocal(ownerKey, server);
      } catch (_) {}
      throw Exception(
        'تاريخ الميلاد مسجَّل بالفعل ولا يمكن تغييره — للتغيير تواصل مع الدار.',
      );
    } catch (_) {
      // الخادم غير متاح أو نقطته غير منشورة — يُحفظ محلياً فقط،
      // وتُعاد مزامنته مع الخادم عند أول تحميل لاحق.
      await _saveLocal(ownerKey, birthday);
      return birthday;
    }
  }

  Future<DateTime?> _loadLocal(String ownerKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$ownerKey');
      if (raw == null || raw.isEmpty) return null;
      return parseBirthday(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLocal(String ownerKey, DateTime birthday) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyPrefix$ownerKey', formatBirthday(birthday));
    } catch (_) {}
  }
}
