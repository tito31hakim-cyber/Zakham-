import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/services/deep_link_service.dart';
import 'package:house_of_zakham/services/favorites_service.dart';
import 'package:house_of_zakham/services/product_api.dart';
import 'package:house_of_zakham/services/product_catalog.dart';
import 'package:house_of_zakham/services/product_share.dart';

Product _productFromNotes(
  String id,
  List<String> top,
  List<String> middle,
  List<String> base, {
  List<String> tags = const <String>[],
  String season = '',
  String occasion = '',
  String name = '',
}) {
  return Product.fromJson(<String, dynamic>{
    'product_id': id,
    'name': name.isEmpty ? id : name,
    'prices': <String, dynamic>{'100': 500},
    'variants': <String, dynamic>{},
    'notes': <String, dynamic>{'top': top, 'middle': middle, 'base': base},
    'tags': tags,
    'season': season,
    'occasion': occasion,
    'visible': true,
    'stockStatus': 'available',
  });
}

class _FailingApi extends ProductApi {
  @override
  Future<String> fetchProductsRaw() async => throw Exception('no network');
}

class _CannedApi extends ProductApi {
  _CannedApi(this.raw);
  final String raw;
  @override
  Future<String> fetchProductsRaw() async => raw;
}

const String _cannedStorefront = '''
{"products": [
  {"product_id": "layl", "name": "ليل زخم", "prices": {"100": 500},
   "variants": {}, "visible": true, "stockStatus": "available",
   "notes": {"top": ["ورد"], "middle": ["عود"], "base": ["مسك"]},
   "tags": ["gender:unisex"], "season": "كل الفصول", "occasion": "يومي ومسائي"},
  {"product_id": "hidden", "name": "مخفي", "prices": {"100": 500},
   "variants": {}, "visible": false, "stockStatus": "available",
   "notes": {"top": [], "middle": [], "base": []}, "tags": []}
]}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('parseProductSlug', () {
    test('product links resolve to the slug', () {
      expect(parseProductSlug(Uri.parse('https://zakhamhouse.shop/product/layl')), 'layl');
      expect(parseProductSlug(Uri.parse('https://zakhamhouse.shop/product/zh-01')), 'zh-01');
      expect(parseProductSlug(Uri.parse('https://www.zakhamhouse.shop/product/sultan')), 'sultan');
      expect(parseProductSlug(Uri.parse('http://zakhamhouse.shop/product/royal')), 'royal');
    });

    test('non-product links are rejected', () {
      expect(parseProductSlug(Uri.parse('https://zakhamhouse.shop/')), isNull);
      expect(parseProductSlug(Uri.parse('https://zakhamhouse.shop/ritual')), isNull);
      expect(parseProductSlug(Uri.parse('https://zakhamhouse.shop/product/')), isNull);
      expect(parseProductSlug(Uri.parse('https://zakhamhouse.shop/product/layl/extra')), isNull);
      expect(parseProductSlug(Uri.parse('https://example.com/product/layl')), isNull);
      expect(parseProductSlug(Uri.parse('https://zakhamhouse.shop/product/LAYL')), isNull);
    });
  });

  group('Product smart-search matching', () {
    final layl = _productFromNotes(
      'layl',
      <String>['برغموت فلفل وردي', 'ورد طائفي'],
      <String>['ياسمين', 'عود'],
      <String>['مسك', 'عنبر'],
    );
    final storm = _productFromNotes(
      'storm',
      <String>['برغموت إيطالي', 'فلفل وردي.'],
      <String>['إكليل الجبل'],
      <String>['المسك الأبيض'],
    );
    final aura = _productFromNotes(
      'aura',
      <String>['الزعفران الأحمر الفاخر'],
      <String>['ياسمين'],
      <String>['المسك البلوري'],
    );
    final royal = _productFromNotes(
      'royal',
      <String>['الكونياك'],
      <String>['التونكا'],
      <String>['العنبر الملكي'],
      season: 'هيبة الملوك، صُمم لليالي الشتوية والمناسبات الرسمية.',
      occasion: 'مناسبات رسمية',
    );

    test('note matching is whole-word based (وردي is not ورد)', () {
      expect(layl.matchesNote('ورد'), isTrue);
      expect(layl.matchesNote('عود'), isTrue);
      expect(layl.matchesNote('مسك'), isTrue);
      expect(layl.matchesNote('عنبر'), isTrue);
      expect(layl.matchesNote('زعفران'), isFalse);
      // «فلفل وردي» لا يطابق «ورد»، و«المسك» يطابق «مسك».
      expect(storm.matchesNote('ورد'), isFalse);
      expect(storm.matchesNote('مسك'), isTrue);
      // «الزعفران» يطابق «زعفران».
      expect(aura.matchesNote('زعفران'), isTrue);
    });

    test('season and occasion substring matching', () {
      expect(royal.matchesSeason('شتو'), isTrue);
      expect(royal.matchesSeason('صيف'), isFalse);
      expect(royal.matchesOccasion('رسمي'), isTrue);
      expect(royal.matchesOccasion('يومي'), isFalse);
    });

    test('gender comes from the server tags', () {
      final male = _productFromNotes('storm', const <String>[], const <String>[], const <String>[], tags: <String>['gender:male']);
      final unisex = _productFromNotes('layl', const <String>[], const <String>[], const <String>[], tags: <String>['gender:unisex']);
      final untagged = _productFromNotes('aura', const <String>[], const <String>[], const <String>[]);
      expect(male.gender, 'male');
      expect(male.genderLabel, 'رجالي');
      expect(unisex.gender, 'unisex');
      expect(unisex.genderLabel, 'للجنسين');
      expect(untagged.gender, '');
      expect(untagged.genderLabel, '');
    });

    test('productUrl is the share/deep-link URL', () {
      expect(layl.productUrl, 'https://zakhamhouse.shop/product/layl');
    });
  });

  group('ProductApi.parseProducts', () {
    test('parses the storefront shape and drops hidden products', () {
      final products = ProductApi.parseProducts(_cannedStorefront);
      expect(products.length, 1);
      expect(products.first.id, 'layl');
      expect(products.first.gender, 'unisex');
      expect(products.first.matchesNote('ورد'), isTrue);
    });
  });

  group('FavoritesService', () {
    test('round-trips favorite ids under the zakham_favorites key', () async {
      final service = FavoritesService();
      expect(await service.load(), isEmpty);
      await service.save(<String>{'layl', 'royal'});
      expect(await service.load(), <String>{'layl', 'royal'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(FavoritesService.storageKey),
          containsAll(<String>['layl', 'royal']));
    });
  });

  group('ProductCatalog offline cache', () {
    test('falls back to the cached catalog when the network fails', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'zakham_storefront_cache_v1': _cannedStorefront,
        'zakham_storefront_cache_time_v1': 0,
      });
      final result =
          await ProductCatalog(api: _FailingApi()).fetchCatalog();
      expect(result.fromCache, isTrue);
      expect(result.products.length, 1);
      expect(result.products.first.id, 'layl');
    });

    test('fresh fetch returns live data and saves the cache', () async {
      final result =
          await ProductCatalog(api: _CannedApi(_cannedStorefront)).fetchCatalog();
      expect(result.fromCache, isFalse);
      expect(result.products.length, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zakham_storefront_cache_v1'),
          _cannedStorefront);
    });

    test('rethrows when the network fails and there is no cache', () async {
      await expectLater(
        ProductCatalog(api: _FailingApi()).fetchCatalog(),
        throwsException,
      );
    });
  });

  group('ProductShare.shareText', () {
    test('builds the Arabic share text with name, price and link', () {
      final product = _productFromNotes('layl', const <String>['ورد'],
          const <String>['عود'], const <String>['مسك'],
          name: 'ليل زخم');
      final text = ProductShare.shareText(product);
      expect(text, contains('ليل زخم'));
      expect(text, contains('500 EGP'));
      expect(text, contains('https://zakhamhouse.shop/product/layl'));
    });
  });
}
