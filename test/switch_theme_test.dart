import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/theme/app_theme.dart';

/// اختبارات ثيم مفتاح التبديل — 2026-11-21.
///
/// الفرق البصري بين التشغيل والإيقاف في «حسابي» و«الإشعارات»
/// (وكل مفاتيح التطبيق) يأتي من `AppTheme.switchTheme` لا من
/// خصائص كل مبدّل على حدة: التشغيل ذهبي (مقبض + مسار)، والإيقاف
/// رمادي (مقبض باهت + مسار خافت بإطار) — في الثيمين الداكن والفاتح.
///
/// ملاحظة: الاختبار يستدعي `switchThemeDark()`/`switchThemeLight()`
/// مباشرة لا `AppTheme.dark()`/`light()`، لأن بناء الثيم الكامل
/// يستدعي `GoogleFonts.tajawalTextTheme` الذي يجدول تحميل الخط
/// دائماً فيفشل في بيئة الاختبار — والقيم المختبرة هنا هي نفسها
/// حرفياً ما يستخدمه الثيمان.
void main() {
  group('مفتاح التبديل: تشغيل ذهبي وإيقاف رمادي', () {
    test('الداكن: المقبض والمسار والإطار تختلف بين الحالتين', () {
      final theme = AppTheme.switchThemeDark();
      final thumb = theme.thumbColor!;
      final track = theme.trackColor!;
      final outline = theme.trackOutlineColor!;
      expect(thumb.resolve({WidgetState.selected}), gold);
      expect(thumb.resolve({WidgetState.selected}),
          isNot(thumb.resolve(<WidgetState>{})));
      expect(track.resolve({WidgetState.selected}),
          isNot(track.resolve(<WidgetState>{})));
      expect(outline.resolve({WidgetState.selected}),
          isNot(outline.resolve(<WidgetState>{})));
    });

    test('الفاتح: المقبض والمسار والإطار تختلف بين الحالتين', () {
      final theme = AppTheme.switchThemeLight();
      final thumb = theme.thumbColor!;
      final track = theme.trackColor!;
      final outline = theme.trackOutlineColor!;
      expect(thumb.resolve({WidgetState.selected}), lightGoldText);
      expect(thumb.resolve({WidgetState.selected}),
          isNot(thumb.resolve(<WidgetState>{})));
      expect(track.resolve({WidgetState.selected}),
          isNot(track.resolve(<WidgetState>{})));
      expect(outline.resolve({WidgetState.selected}),
          isNot(outline.resolve(<WidgetState>{})));
    });
  });
}
