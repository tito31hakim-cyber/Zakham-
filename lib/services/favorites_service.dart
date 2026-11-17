import 'package:shared_preferences/shared_preferences.dart';

/// المفضلة — محلية فقط، بلا أي اتصال بالخادم. تُحفظ معرّفات المنتجات
/// (product_id، وهو نفسه slug رابط المنتج) في SharedPreferences.
/// أي فشل في التخزين يُتجاهل: المفضلة تحسين لا يمنع استخدام التطبيق.
class FavoritesService {
  static const storageKey = 'zakham_favorites';

  Future<Set<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(storageKey);
      if (ids == null) return <String>{};
      return ids.where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> save(Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        storageKey,
        ids.where((id) => id.isNotEmpty).toList(growable: false),
      );
    } catch (_) {
      // تجاهل صامت — تُعاد المحاولة عند التبديل التالي.
    }
  }
}
