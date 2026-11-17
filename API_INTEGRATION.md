# تكامل API — House of Zakham

## الاستضافة

النسخة الحالية من الخلفية مستضافة على الخادم المرتبط بالنطاق zakhamhouse.shop وتستخدم `api.php` مع قواعد إعادة الكتابة الموجودة في `.htaccess`.

العنوان الأساسي:

```text
https://zakhamhouse.shop
```

تستخدم تطبيقات Flutter المسارات التالية:

| الوظيفة | الطريقة | المسار |
|---|---:|---|
| فحص الخدمة | GET | `/api/health` |
| كتالوج المنتجات | GET | `/api/storefront` |
| إنشاء طلب | POST | `/api/orders` |
| تسجيل دخول الإدارة | GET | `/api/analytics` مع `X-Admin-Token` |
| منتجات الإدارة | GET | `/api/admin/products` |
| تعديل منتج | PATCH | `/api/admin/products/{id}` |
| إخفاء منتج | DELETE | `/api/admin/products/{id}` |
| العملاء | GET | `/api/admin/customers?q=...` |

يتم تجميع العناوين في `lib/config/app_config.dart`، ولا ينبغي كتابة مسارات API داخل صفحات الواجهة.

## شكل الكتالوج

يرد `/api/storefront` بالشكل التالي (تشكيلة 2027 — 11 عطراً، كلها
`visible: true` و`stockStatus: "available"` وقت آخر فحص):

```json
{
  "settings": {},
  "products": [
    {
      "id": "royal",
      "name": "زَخَم رويال",
      "en": "ZAKHAM ROYAL",
      "image": "/assets/products/catalog-royal-2026.jpg",
      "category": "official",
      "categoryLabel": "كتالوج زخم الرسمي 2027",
      "season": "وصف العطر",
      "occasion": "مناسبات رسمية",
      "lasting": "شتوي / مسائي",
      "defaultConcentration": "presence",
      "visible": true,
      "stockStatus": "available",
      "notes": {
        "top": "نفحات البداية",
        "middle": "قلب العطر",
        "base": "القاعدة"
      },
      "prices": {"30": "250", "50": 350, "100": "500"},
      "variants": {
        "presence": {
          "label": "حُضور · Eau de Parfum",
          "labelEn": "Eau de Parfum",
          "prices": {"30": "250", "50": "350", "100": "500"}
        },
        "extra": {
          "label": "فَوْحان · Extrait Prime Parfum",
          "labelEn": "Extrait Prime Parfum",
          "prices": {"30": 350, "50": 500, "100": 700}
        },
        "nuclear": {
          "label": "نووي · Extrait Max Parfum",
          "labelEn": "Extrait Max Parfum",
          "prices": {"50": 650, "100": 950}
        }
      }
    }
  ]
}
```

قواعد شكل الرد التي يعتمد عليها التطبيق:

- **الأسعار نصية أو رقمية**: قيمة السعر قد تكون `"500"` أو `500`، داخل
  `prices` وداخل `variants[concentration].prices` — يحوّلها
  `Product.toDouble` في الحالتين، وأي سعر نصي غير رقمي يُتجاهل.
- **لا `perfumeCode` ولا `qrPayload` ولا `stockQty`** في الرد العام
  إطلاقاً (أُزيلت من `/api/storefront`) — لا يعتمد عليها أي كود، ولا
  تُطلب، ولا تُرسل في الطلبات (الخادم يشتق كود الزجاجة من قاعدته).
- **التركيزات الثلاثة وأسعارها** (جنيه مصري، موحّدة لكل العطور):

  | التركيز | 30 مل | 50 مل | 100 مل |
  |---|---:|---:|---:|
  | presence — حُضور (Eau de Parfum) | 250 | 350 | 500 |
  | extra — فَوْحان (Extrait Prime) | 350 | 500 | 700 |
  | nuclear — نووي (Extrait Max) | — | 650 | 950 |

  النووي بلا حجم 30 مل؛ صفحة المنتج تخفي الحجم غير المتاح للتركيز
  المختار. `defaultConcentration` يأتي من الرد (حالياً `presence`
  لكل العطور).
- **النوتات**: `notes.top/middle/base` قد تكون نصاً واحداً أو قائمة
  نصوص — يقبل `Product.fromJson` الصيغتين.
- **الحقول الوصفية**: `en` (الاسم الإنجليزي)، و`categoryLabel`
  («كتالوج زخم الرسمي 2027» أو «Extrait Premium» أو «خط المسك»)،
  و`season` (النسخة الوصفية للعطر)، و`occasion`، و`lasting`
  (مثل «8–12 ساعة»).
- **الظهور والتوفر**: المنتجات ذات `visible == false` تُستبعد من
  التشكيلة في `ProductApi`؛ والتوفر من `stockStatus == "available"`.

يتولى `Product.fromJson` تحويل صيغ الاستضافة إلى نموذج Flutter، بما في ذلك:

- `notes.top/middle/base` (نص أو قائمة).
- `prices` و`variants` بأسعار نصية/رقمية.
- `visible` و`stockStatus` و`defaultConcentration`.
- `en` و`categoryLabel` و`occasion` و`lasting`.
- الصور النسبية تحت `/assets/products/` (اسم ملف رويال الحي ما زال
  `catalog-royal-2026.jpg` رغم أنه من تشكيلة 2027 — لا تُعاد تسميته
  من التطبيق).

## الطلبات

يرسل تطبيق Flutter الطلبات إلى `/api/orders` باستخدام JSON. مثال صنف:

```json
{
  "productId": "royal",
  "nameAr": "زَخَم رويال",
  "nameEn": "ZAKHAM ROYAL",
  "sizeMl": 50,
  "concentration": "extra",
  "quantity": 1,
  "unitPrice": 500,
  "lineTotal": 500
}
```

قواعد الطلبات في الخادم الحي:

- **وسيلة الدفع**: يقبل الخادم حصراً هاتين القيمتين حرفياً، وأي قيمة
  أخرى تُرفض `422 invalid_payment_method`:
  `InstaPay | إنستاباي` و`Vodafone Cash | فودافون كاش` — الدفع مسبق
  فقط، ولا يوجد دفع عند الاستلام. يتحقق `OrderApi` من القيمة قبل الإرسال.
- **الشحن موحّد 120 ج.م** لجميع المحافظات؛ يرسل التطبيق
  `shippingFee: 120`، والخادم يعيد حساب الشحن والإجمالي بنفسه من
  المحافظة قبل الحفظ.
- **الخادم يعيد تسعير كل صنف** من (الحجم، التركيز) ويرفض التركيبة غير
  المتاحة `422 invalid_variant` والمنتج غير المتاح `409`؛ لذلك يرسل
  التطبيق دائماً التركيز والحجم المختارين فعلاً وسعر الوحدة المطابق لهما.
- الكمية لكل صنف 1–20، وإجمالي الكميات 30 كحد أقصى.
- الخادم الحالي يقبل بيانات العميل والعناصر والمجموع والإجمالي، لذلك يجب أن تبقى إعادة حساب الأسعار والإجمالي على الخادم قبل اعتماد الطلب في بيئة الإنتاج.

## الإدارة

تتحقق `api.php` من رمز الإدارة عبر الترويسة:

```text
X-Admin-Token: <admin token>
```

يجب عدم تخزين رمز الإدارة داخل التطبيق أو تضمينه في الكود؛ صفحة الإدارة الحالية تطلبه من المستخدم، ويجب إضافة جلسة قصيرة العمر أو آلية تدوير للرمز قبل النشر الإنتاجي.

## ترويسات Flutter للمصادقة وCSRF

تستخدم طبقة `lib/services/api_headers.dart` ترويسات موحدة:

```text
Authorization: Bearer <access token>
X-Admin-Token: <admin token>
X-CSRF-Token: <server-issued csrf token>
```

يتم إرسال `X-CSRF-Token` فقط مع الطلبات المعدِّلة مثل `PATCH` و`DELETE` و`POST`. رمز الإدارة ورمز CSRF يبقيان في الذاكرة فقط ولا يتم حفظهما في `SharedPreferences` أو طباعتهما في السجلات.

مثال الاستخدام:

```dart
final api = AdminApi(
  token: adminTokenFromSession,
  csrfToken: csrfTokenReturnedByPhpSession,
);
```

يجب أن يصدر الخادم رمز CSRF بعد إنشاء جلسة الإدارة. لا يجوز استخدام رمز الإدارة نفسه كرمز CSRF. الإضافة في Flutter متوافقة مع PHP الحالي، لكن تفعيل التحقق الفعلي من CSRF يتطلب إضافة `requireCsrf()` في `api.php` على مسارات `PATCH` و`DELETE` و`POST`.
