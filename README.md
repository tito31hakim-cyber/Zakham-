# house_of_zakham — تطبيق دار زخم للعطور

تطبيق Flutter الرسمي لمتجر دار زخم (zakhamhouse.shop): تشكيلة 2027 — 11 عطراً،
الدفع المسبق عبر إنستاباي أو فودافون كاش، والشحن 120 ج.م لجميع محافظات مصر.

البناء والإصدار عبر Codemagic (ينتج AAB وAPK معاً) — انظر `codemagic.yaml`
و`API_INTEGRATION.md` لشكل رد الخادم الحي.

## البناء

### عبر Codemagic (الطريقة المعتمدة)

الدفع إلى الفرع `main` يبني تلقائياً (انظر `codemagic.yaml`):

- **Android:** حزمة AAB موقعة + ملف APK موقع (`app-release.apk`) — ملف APK المنشور على الموقع `/downloads/zakhamhouse.apk` يأتي من هذا البناء.
- **iOS:** ملف IPA موقع عبر App Store Connect.

### بناء محلي

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release      # APK
flutter build appbundle --release # AAB لمتجر Google Play
```

توقيع نسخة الإصدار محلياً يتطلب `android/key.properties` (مفتاح التوقيع غير مرفوع للمستودع — انظر `android/key.properties.example`). عبر Codemagic يُستخدم مفتاح التوقيع المحفوظ هناك.

## بيانات المتجر

- النطاق: `https://zakhamhouse.shop` — واجهة الكتالوج `GET /api/storefront` والطلبات `POST /api/orders` (التفاصيل في `API_INTEGRATION.md`).
- الشحن: 120 ج.م لجميع المحافظات. الدفع المسبق: إنستاباي أو فودافون كاش فقط.
- الخط: Tajawal (نفس خط الموقع) عبر حزمة `google_fonts` — يُحمَّل من Google Fonts ويُخزَّن على الجهاز بعد أول تشغيل، ومفعّل في `lib/theme/app_theme.dart`.
