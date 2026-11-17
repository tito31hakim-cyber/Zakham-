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

## لوحة الإدارة (داخل التطبيق)

من `حسابي ← دخول الإدارة` — الدخول ببريد الإدارة وكلمة المرور (نفس
حساب لوحة تحكم الموقع)، مع دعم رمز التحقق الثنائي عند طلبه. اللوحة
تعرض الإحصاءات (الطلبات، الإيرادات، بانتظار الدفع، تم التوصيل) وثلاثة
أقسام: المنتجات (تعديل الاسم والمخزون والظهور، مع حارس يمنع الحفظ
عند غياب حقول المخزون وكود الأصالة الإدارية من الخادم)، والعملاء
(بحث بالاسم أو البريد)، والطلبات (تصفية بالحالة، تفاصيل الطلب كاملة،
تغيير الحالة حسب قواعد الخادم، وتأكيد/رفض/استرداد الدفع).

## الإشعارات الفورية

يطبّق التطبيق طرف العميل كاملاً (Firebase Cloud Messaging): إذن
الإشعارات، رمز الجهاز، عرض الرسائل في المقدمة والخلفية، واشتراكات
المواضيع (تحديثات الطلبات، العروض، وصل حديثاً)، وصفحة إعدادات من
`حسابي ← الإشعارات` فيها زر اختبار.

التفعيل يحتاج ملفات Firebase من مشروع الدار (لا يمكن توليدها من
المستودع): ضع `google-services.json` في `android/app/` و
`GoogleService-Info.plist` في `ios/Runner/`، وأضف في
`android/settings.gradle` ضمن `plugins`:

```gradle
id "com.google.gms.google-services" version "4.4.2" apply false
```

وفي `android/app/build.gradle.kts` ضمن `plugins`:

```kotlin
id("com.google.gms.google-services")
```

بدون هذه الملفات يعمل التطبيق طبيعياً وتظهر صفحة الإشعارات أن الخدمة
غير مفعّلة بعد. إرسال الرسائل نفسه يحتاج نقطة إرسال FCM على الخادم
(خطوة خادم مستقلة — انظر `API_INTEGRATION.md`).

## بيانات المتجر

- النطاق: `https://zakhamhouse.shop` — واجهة الكتالوج `GET /api/storefront` والطلبات `POST /api/orders` (التفاصيل في `API_INTEGRATION.md`).
- الشحن: 120 ج.م لجميع المحافظات. الدفع المسبق: إنستاباي أو فودافون كاش فقط.
- الخط: Tajawal (نفس خط الموقع) عبر حزمة `google_fonts` — يُحمَّل من Google Fonts ويُخزَّن على الجهاز بعد أول تشغيل، ومفعّل في `lib/theme/app_theme.dart`.
