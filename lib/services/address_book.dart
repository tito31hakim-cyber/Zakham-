import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_address.dart';
import 'customer_auth.dart';

/// دفتر العناوين: الخادم أولاً، والتخزين المحلي احتياطاً.
///
/// يجرب نقطة `/api/account/addresses` بجلسة العميل؛ إن غابت (404 —
/// الخادم لم يُنشر بعد) أو فشل الاتصال، يسقط للتخزين المحلي بهدوء
/// دون كسر أي شاشة. التخزين المحلي مفتاحه بحساب العميل
/// (`zakham_addresses_v1_<openId>`) حتى لا تتسرب عناوين حساب إلى آخر
/// على الجهاز نفسه. عنوان واحد فقط افتراضي؛ تعيين افتراضي جديد يلغي
/// السابق (على الخادم والمحلي معاً).
class AddressBookService {
  AddressBookService(this._auth);

  final CustomerAuth _auth;

  /// true بعد تحميل ناجح من الخادم؛ الكتابة تجرب الخادم أولاً حينها.
  bool _serverAvailable = false;

  bool get serverAvailable => _serverAvailable;

  String _localKey(String ownerKey) => 'zakham_addresses_v1_$ownerKey';

  Future<List<SavedAddress>> load({required String ownerKey}) async {
    try {
      final rows = await _auth.fetchAddresses();
      _serverAvailable = true;
      final addresses =
          rows.map(SavedAddress.fromJson).toList(growable: false);
      // نسخة محلية احتياطية دائماً — تُستخدم إن تعذّر الخادم لاحقاً.
      await _saveLocal(ownerKey, addresses);
      return _sorted(addresses);
    } catch (_) {
      _serverAvailable = false;
      return _sorted(await _loadLocal(ownerKey));
    }
  }

  Future<SavedAddress> save({
    required String ownerKey,
    required SavedAddress address,
  }) async {
    // معرّف محلي (local_…) لا وجود له على الخادم بعد — يُنشأ هناك،
    // أما معرّف الخادم (رقم) فيُحدَّث. محلياً يُعاد استخدام المعرّف
    // نفسه دائماً وإلا تكرر العنوان عند كل تعديل.
    final isNewOnServer =
        address.id.isEmpty || address.id.startsWith('local_');
    if (_serverAvailable) {
      try {
        final saved = isNewOnServer
            ? await _auth.createAddress(address.toRequestJson())
            : await _auth.updateAddress(address.id, address.toRequestJson());
        final result = SavedAddress.fromJson(saved);
        if (result.id.isNotEmpty) return result;
      } catch (_) {
        _serverAvailable = false;
      }
    }
    final current = await _loadLocal(ownerKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = address.id.isEmpty
        ? 'local_${now}_${Random().nextInt(100000)}'
        : address.id;
    final saved = address.copyWith(id: id);
    final updated = <SavedAddress>[];
    var replaced = false;
    for (final item in current) {
      if (item.id == id) {
        updated.add(saved);
        replaced = true;
      } else {
        updated.add(
          saved.isDefault && item.isDefault
              ? item.copyWith(isDefault: false)
              : item,
        );
      }
    }
    if (!replaced) updated.add(saved);
    await _saveLocal(ownerKey, updated);
    return saved;
  }

  Future<void> delete({
    required String ownerKey,
    required String id,
  }) async {
    if (_serverAvailable && !id.startsWith('local_')) {
      try {
        await _auth.deleteAddress(id);
        await load(ownerKey: ownerKey);
        return;
      } catch (_) {
        _serverAvailable = false;
      }
    }
    final current = await _loadLocal(ownerKey);
    current.removeWhere((item) => item.id == id);
    await _saveLocal(ownerKey, current);
  }

  Future<void> setDefault({
    required String ownerKey,
    required String id,
  }) async {
    final current = await load(ownerKey: ownerKey);
    SavedAddress? target;
    for (final item in current) {
      if (item.id == id) target = item;
    }
    if (target == null) return;
    await save(ownerKey: ownerKey, address: target.copyWith(isDefault: true));
  }

  List<SavedAddress> _sorted(List<SavedAddress> addresses) {
    final sorted = List<SavedAddress>.from(addresses);
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.label.compareTo(b.label);
    });
    return sorted;
  }

  Future<List<SavedAddress>> _loadLocal(String ownerKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey(ownerKey));
      if (raw == null || raw.isEmpty) return const <SavedAddress>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SavedAddress>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedAddress.fromJson)
          .toList();
    } catch (_) {
      return const <SavedAddress>[];
    }
  }

  Future<void> _saveLocal(
    String ownerKey,
    List<SavedAddress> addresses,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localKey(ownerKey),
        jsonEncode(addresses.map((item) => item.toJson()).toList()),
      );
    } catch (_) {}
  }
}
