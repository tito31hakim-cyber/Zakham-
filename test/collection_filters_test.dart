import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/models/product.dart';
import 'package:house_of_zakham/pages/collection_page.dart';

/// اختبارات عدّادات «تصفية ذكية» — مراجعة 2026-11-21 ضد الكتالوج الحي.
///
/// تشكيلة 2027 (11 عطراً) كما في `/api/storefront` الحي:
/// النوتات: عود 3، مسك 5، عنبر 7، ورد 3، زعفران 1.
/// النوع: للجنسين 4، رجالي 1، نسائي 0، و6 عطور بلا وسم نوع على
/// الخادم — يغطيها خيار «غير محدد» حتى يجمع العدّاد 11 كلها.

Product _perfume(
  String id,
  List<String> notes,
  List<String> tags, {
  Map<String, dynamic> variants = const <String, dynamic>{},
}) =>
    Product(
      id: id,
      name: id,
      price: 250,
      currency: 'EGP',
      size: '30',
      category: 'official',
      topNotes: notes,
      heartNotes: const <String>[],
      baseNotes: const <String>[],
      image: '',
      inStock: true,
      tags: tags,
      variants: variants,
    );

/// التشكيلة الـ 11 بوسوم النوع الحية ونوتات مختصرة تحافظ على
/// العدّادات الحية (الكلمة الكاملة مع «ال» أو بدونها).
List<Product> _liveCollection() => <Product>[
      _perfume('layl', ['عود', 'مسك', 'عنبر', 'ورد'], ['gender:unisex']),
      _perfume('elixir', ['عنبر'], const <String>[]),
      _perfume('sultan', ['عود', 'مسك', 'عنبر'], const <String>[]),
      _perfume('royal', ['عنبر'], ['gender:unisex']),
      _perfume('storm', ['مسك'], ['gender:male']),
      _perfume('aura', ['مسك', 'عنبر', 'زعفران'], const <String>[]),
      _perfume('aurora', const <String>[], const <String>[]),
      _perfume('fares', ['عود', 'ورد'], const <String>[]),
      _perfume('tobacco', ['عنبر'], ['gender:unisex']),
      _perfume('fahd', ['عنبر', 'ورد'], const <String>[]),
      _perfume('musk', ['مسك'], ['gender:unisex']),
    ];

void main() {
  group('النوع — عدّاد يغطي التشكيلة كلها', () {
    const genderOptions = <(String, String)>[
      ('رجالي', 'male'),
      ('نسائي', 'female'),
      ('للجنسين', 'unisex'),
      ('غير محدد', ''),
    ];

    test('للجنسين 4 + رجالي 1 + غير محدد 6 = 11، ونسائي مخفي (0)', () {
      final options = filterOptionsWithCounts(
        _liveCollection(),
        genderOptions,
        (product, value) => product.gender == value,
      );
      final counts = {for (final o in options) o.$2: o.$3};
      expect(counts['unisex'], 4);
      expect(counts['male'], 1);
      expect(counts[''], 6);
      expect(counts.containsKey('female'), isFalse);
      expect(
        options.fold<int>(0, (sum, o) => sum + o.$3),
        11,
      );
    });

    test('النوع من الوسوم: male/female/unisex، أو فارغ بلا وسم', () {
      expect(
        _perfume('a', const [], ['gender:male']).gender,
        'male',
      );
      expect(
        _perfume('b', const [], ['gender:female']).gender,
        'female',
      );
      expect(
        _perfume('c', const [], ['gender:unisex']).gender,
        'unisex',
      );
      expect(_perfume('d', const [], const []).gender, '');
    });
  });

  group('النوتة — عدّادات الكتالوج الحي', () {
    const noteOptions = <(String, String)>[
      ('عود', 'عود'),
      ('مسك', 'مسك'),
      ('عنبر', 'عنبر'),
      ('ورد', 'ورد'),
      ('زعفران', 'زعفران'),
    ];

    test('عود 3، مسك 5، عنبر 7، ورد 3، زعفران 1', () {
      final options = filterOptionsWithCounts(
        _liveCollection(),
        noteOptions,
        (product, keyword) => product.matchesNote(keyword),
      );
      final counts = {for (final o in options) o.$2: o.$3};
      expect(counts, <String, int>{
        'عود': 3,
        'مسك': 5,
        'عنبر': 7,
        'ورد': 3,
        'زعفران': 1,
      });
    });
  });

  group('بطاقة التشكيلة — سطر تركيز واحد مختصر', () {
    test('ثلاثة تركيزات → «حُضور · فَوْحان · نووي» بلا تسميات الخادم', () {
      final product = _perfume('x', const [], const [], variants: {
        'presence': {
          'label': 'حُضور · Eau de Parfum',
          'prices': {'30': 250},
        },
        'extra': {
          'label': 'فَوْحان · Extra Perfume',
          'prices': {'30': 350},
        },
        'nuclear': {
          'label': 'نووي · Extra Max Perfume',
          'prices': {'50': 700},
        },
      });
      expect(
        product.availableConcentrationsShort,
        'حُضور · فَوْحان · نووي',
      );
    });

    test('تركيز واحد → اسمه المختصر فقط', () {
      final product = _perfume('y', const [], const [], variants: {
        'presence': {
          'label': 'حُضور · Eau de Parfum',
          'prices': {'30': 250},
        },
      });
      expect(product.availableConcentrationsShort, 'حُضور');
    });
  });
}
