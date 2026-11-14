# تطبيق دار زخم للعطور

تطبيق Flutter متعدد المنصات لدار زخم، بهوية داكنة سوداء مع تفاصيل ذهبية وعنابية، وواجهة عربية من اليمين إلى اليسار. يوفر استعراض التشكيلة وصفحات المنتجات والمفضلة واختبار اختيار العطر والسلة والحساب.

## التشغيل والتطوير

يتطلب المشروع Flutter SDK مطابقًا لقيد Dart في `pubspec.yaml`. لتشغيله محليًا:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter analyze
flutter test
flutter run
```

يُدار اسم التطبيق وألوان العلامة في `lib/theme/app_theme.dart` و`lib/config/app_config.dart`. ملف شعار العلامة المستخدم في الواجهة هو `assets/brand/zakham-brand-mark.png`، وإعدادات إنشاء أيقونات المنصات موجودة في `pubspec.yaml`.

## البناء والتوقيع

يعرّف `codemagic.yaml` بناء Android App Bundle موقّعًا وبناء iOS IPA. يجب إعداد مفاتيح توقيع Android وiOS في Codemagic قبل إصدار حزم التوزيع. يعمل البناء على توليد أيقونات العلامة، ثم تحليل المشروع وتشغيل الاختبارات قبل إنتاج الحزمة.

لا يحتوي جذر المشروع على ملف CMake؛ البناء الصحيح لهذا المشروع هو عبر Flutter. عنوان API الحالي مضبوط في `lib/config/app_config.dart` على `https://zakhamhouse.shop`، وتوثيق المسارات موجود في `API_INTEGRATION.md`.
