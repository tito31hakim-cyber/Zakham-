import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/utils/chat_text_sanitize.dart';

/// اختبارات دالة تنظيف ردود المحادثة قبل عرضها.
///
/// ما يثبته الاختبار: رموز Markdown الخام (| و** و# وسطور فواصل
/// الجداول) تُزال، بينما تبقى فواصل الأسطر وبنية الفقرات كما هي،
/// والنص العادي بلا رموز لا يتغيّر إطلاقاً.

void main() {
  group('sanitizeChatText', () {
    test('يزيل علامتي التأكيد ** ويبقي النص', () {
      expect(
        sanitizeChatText('جرّب **زخم رويال** — ورد وعنبر.'),
        'جرّب زخم رويال — ورد وعنبر.',
      );
    });

    test('يزيل أنابيب الجدول ويسقط سطر الفاصل', () {
      expect(
        sanitizeChatText(
          '| العطر | النوتة |\n|---|---|\n| **زخم رويال** | ورد وعنبر |',
        ),
        'العطر النوتة\nزخم رويال ورد وعنبر',
      );
    });

    test('يزيل علامات العناوين # في بداية السطر', () {
      expect(
        sanitizeChatText('## ترشيحات الليلة\n# عنوان آخر\nنص عادي'),
        'ترشيحات الليلة\nعنوان آخر\nنص عادي',
      );
    });

    test('يحافظ على فواصل الأسطر والفقرات', () {
      const raw = 'فقرة أولى بسطرين.\nوهذا سطرها الثاني.\n\nفقرة ثانية منفصلة.\n\n\nفقرة ثالثة بعد فراغين.';
      expect(
        sanitizeChatText(raw),
        'فقرة أولى بسطرين.\nوهذا سطرها الثاني.\n\nفقرة ثانية منفصلة.\n\nفقرة ثالثة بعد فراغين.',
      );
    });

    test('النص العادي بلا رموز لا يتغيّر', () {
      const plain = 'جرّب زخم رويال — ورد وعنبر وعود.\n\nسطر ثانٍ.';
      expect(sanitizeChatText(plain), plain);
    });

    test('يزيل علامات الكود ` والخطوط الأفقية', () {
      expect(
        sanitizeChatText('جرّب `إلكسير` الليلة.\n---\nسطر أخير.'),
        'جرّب إلكسير الليلة.\nسطر أخير.',
      );
    });

    test('رد مستشار كامل برموز خام يخرج نظيفاً بفقراته', () {
      const raw = '## ترشيحات الليلة\n\n'
          '| العطر | النوتة |\n|---|---|\n| **زخم رويال** | ورد وعنبر |\n\n'
          'جرّب **إلكسير القوة** — تابلي قوي.\n\nوهذا سطر أخير.';
      expect(
        sanitizeChatText(raw),
        'ترشيحات الليلة\n\nالعطر النوتة\nزخم رويال ورد وعنبر\n\n'
        'جرّب إلكسير القوة — تابلي قوي.\n\nوهذا سطر أخير.',
      );
      final clean = sanitizeChatText(raw);
      expect(clean.contains('|'), isFalse);
      expect(clean.contains('**'), isFalse);
      expect(clean.contains('#'), isFalse);
    });

    test('نص فارغ أو فراغات فقط يخرج فارغاً', () {
      expect(sanitizeChatText(''), isEmpty);
      expect(sanitizeChatText('   \n\n  '), isEmpty);
    });
  });
}
