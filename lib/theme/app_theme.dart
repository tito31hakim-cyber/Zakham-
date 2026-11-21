import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const gold = Color(0xFFC9A45C);
const cream = Color(0xFFF5EFE5);
const muted = Color(0xFF9D978E);
const card = Color(0xFF171615);

/// لوحة الواجهة الفاتحة — من ثيم الموقع الفاتح نفسه (theme-light.css):
/// خلفية عاجية #FFFDF9/#F5EFE5، نص بني داكن #2B211E، نص ثانوي #6F6259،
/// وذهبي داكن #8B5D15 للنصوص والأيقونات الذهبية على الخلفية الفاتحة.
const lightInk = Color(0xFF2B211E);
const lightMuted = Color(0xFF6F6259);
const lightCard = Color(0xFFFFFDF9);
const lightGoldText = Color(0xFF8B5D15);
const lightBorder = Color(0xFFC9B99B);
const darkNavBar = Color(0xFF101010);

/// ألوان تتبع الثيم الحالي عبر `Theme.of(context)` — استخدمها بدل
/// الثوابت `cream`/`muted`/`card`/`gold` في أي نص أو خلفية تظهر على
/// خلفية الصفحة أو البطاقة، حتى لا يختفي النص عند التبديل للفاتح.
/// الثوابت نفسها تبقى للاستخدام على الخلفيات الداكنة الثابتة
/// (صور العطور والتدرجات السوداء فوقها، شارات ذهبية).
extension ZakhamColors on BuildContext {
  bool get isLightTheme => Theme.of(this).brightness == Brightness.light;

  /// لون النص الأساسي: كريمي على الداكن، بني داكن على الفاتح.
  Color get ink => isLightTheme ? lightInk : cream;

  /// لون النص الثانوي.
  Color get subdued => isLightTheme ? lightMuted : muted;

  /// خلفية البطاقات والحقول.
  Color get surfaceCard => isLightTheme ? lightCard : card;

  /// ذهبي للنصوص والأيقونات (أغمق على الفاتح ليُقرأ بوضوح).
  Color get goldText => isLightTheme ? lightGoldText : gold;

  /// حدود خفيفة (بديل Colors.white12).
  Color get hairline =>
      isLightTheme ? lightBorder.withOpacity(.45) : Colors.white12;

  /// حدود أخف (بديل Colors.white10).
  Color get hairlineSoft =>
      isLightTheme ? lightBorder.withOpacity(.28) : Colors.white10;
}

class AppTheme {
  AppTheme._();

  /// ثيم مفتاح التبديل (الداكن) كدالة مستقلة: التشغيل ذهبي
  /// (مقبض + مسار) والإيقاف رمادي (مقبض باهت + مسار خافت بإطار).
  /// الاستقلال عن `dark()` مقصود: بناء الثيم الكامل يستدعي
  /// `GoogleFonts.tajawalTextTheme` الذي يجدول تحميل الخط دائماً
  /// فيفشل أي اختبار يبنيه في بيئة الاختبار — أما هنا فالقيم
  /// نفسها حرفياً بلا أي تحميل.
  static SwitchThemeData switchThemeDark() => SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? gold : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? gold.withOpacity(.35)
              : Colors.white24,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : Colors.white38,
        ),
      );

  /// ثيم مفتاح التبديل (الفاتح) — نفس الفكرة والقيم الذهبية
  /// الداكنة للقراءة على الفاتح.
  static SwitchThemeData switchThemeLight() => SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? lightGoldText
              : lightMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? gold.withOpacity(.45)
              : lightBorder.withOpacity(.55),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : lightBorder,
        ),
      );

  static ThemeData dark() {
    final base = ThemeData.dark();
    return ThemeData(
        brightness: Brightness.dark,
        // خط Tajawal الرسمي للدار (نفس خط الموقع) عبر حزمة google_fonts.
        fontFamily: 'Tajawal',
        textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0B0B),
          foregroundColor: cream,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: card,
          hintStyle: const TextStyle(color: muted),
          labelStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: gold),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: const Color(0xFF17130B),
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardThemeData(
          color: card,
          elevation: 0,
          // زوايا موحدة 20 لكل بطاقات التطبيق (مطابقة لحاويات
          // الأقسام) — البطاقات ذات الشكل الخاص تحتفظ بشكلها.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        // مفتاح التبديل: التشغيل ذهبي (مقبض + مسار ذهبي) والإيقاف
        // رمادي (مقبض باهت + مسار خافت بإطار) — فرق بصري واضح.
        switchTheme: switchThemeDark(),
        useMaterial3: true,
      );
  }

  /// الواجهة الفاتحة — عاجية دافئة على هوية زخم (نفس ثيم الموقع):
  /// خلفية `cream`، بطاقات بيضاء عاجية، نص بني داكن، وذهبي داكن
  /// للنصوص الذهبية حتى تبقى مقروءة على الفاتح.
  static ThemeData light() {
    final base = ThemeData.light();
    return ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Tajawal',
        textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: lightInk,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lightCard,
          hintStyle: const TextStyle(color: lightMuted),
          labelStyle: const TextStyle(color: lightMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: lightBorder.withOpacity(.45)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: lightBorder.withOpacity(.45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: lightGoldText),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: const Color(0xFF17130B),
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: CardThemeData(
          color: lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        // مفتاح التبديل (الفاتح): التشغيل ذهبي داكن والإيقاف رمادي
        // بمسار خافت بإطار — نفس الفرق البصري الواضح.
        switchTheme: switchThemeLight(),
        useMaterial3: true,
      );
  }
}
