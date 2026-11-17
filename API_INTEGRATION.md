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
| جلسة الإدارة | GET | `/api/admin/session` |
| تسجيل دخول الإدارة | POST | `/api/admin/login` |
| تسجيل خروج الإدارة | POST | `/api/admin/logout` |
| إحصاءات الإدارة | GET | `/api/analytics` |
| منتجات الإدارة | GET | `/api/admin/products` |
| تعديل منتج | PATCH | `/api/admin/products/{id}` |
| إخفاء منتج | DELETE | `/api/admin/products/{id}` |
| العملاء | GET | `/api/admin/customers?q=...` |
| بحث الطلبات (الإدارة) | POST | `/api/admin/orders/search` |
| تفاصيل طلب (الإدارة) | GET | `/api/admin/orders/{orderRef}` |
| تغيير حالة طلب | PATCH | `/api/orders/{orderRef}/status` |
| مراجعة دفع طلب | PATCH | `/api/orders/{orderRef}/payment` |

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

> **تنبيه (2026-11-17):** نقطة `GET /api/admin/products` تشارك مسلسل
> `productRow` نفسه مع واجهة المتجر العامة، فبعد إزالة حقول الأصالة
> والمخزون الدقيق من الرد العام لم يعد الرد الإداري يحمل `stockQty`
> ولا `codePrefix`/`codeNumber`/`bottleLabel` (تأكد حياً من الكود).
> ومعالج `PATCH` في الخادم يكتب هذه الحقول من جسم الطلب دون حفظ
> القيم القديمة عند غيابها — فحفظ أي تعديل من التطبيق في هذه الحالة
> سيمسح مخزون المنتج (0 + «غير متوفر») وكود أصالته. لذلك ترفض صفحة
> الإدارة في التطبيق (`_hasAdminFields` في `lib/pages/admin_page.dart`)
> فتح نافذة التعديل عند غياب هذه الحقول، ويُشتق المخزون للعرض فقط من
> `variantRows` (ترد من استعلام منفصل لم يُمس). **الإصلاح الصحيح
> خادمي**: أن يعيد مسار `/api/admin/products` هذه الحقول، وتُحذف من
> الرد العام فقط — لا من `productRow` المشترك.

تتحقق `api.php` من الإدارة بجلسة PHP وليس برمز ترويسة — تحقّق حياً
(2026-11-17): `GET /api/admin/session` يعيد `loginCsrfToken` دون
مصادقة، و`POST /api/admin/login` يقبل البريد وكلمة المرور، و`GET
/api/analytics` دون جلسة يعيد `401`. ترويسة `X-Admin-Token` **لا
يقرأها الخادم إطلاقاً** — النسخ القديمة من هذا الملف والتطبيق التي
ذكرتها كانت خاطئة.

تدفق الدخول (يطبّقه `lib/services/admin_api.dart`):

```text
1. GET  /api/admin/session
   -> Set-Cookie: PHPSESSID=... + { loginCsrfToken }
2. POST /api/admin/login  { email, password, totp? }
   Headers: Cookie: PHPSESSID=... + X-CSRF-Token: <loginCsrfToken>
   -> { ok, csrfToken, user }
3. كل طلب لاحق: Cookie: PHPSESSID=...
   والطلبات المعدِّلة أيضاً: X-CSRF-Token: <csrfToken>
4. POST /api/admin/logout  (ينهي الجلسة)
```

- الحساب المحمي بتحقق ثنائي يعيد `401 admin_totp_required` — عندها
  يُعاد الدخول مع `totp` (رمز تطبيق المصادقة). التسجيل في التحقق
  الثنائي يتم من صفحة الويب `/zk-2fa.php`.
- الجلسة (الكوكي ورموز CSRF) تبقى في الذاكرة فقط ولا تُحفظ في
  `SharedPreferences` ولا تُطبع في السجلات؛ تنتهي بإغلاق التطبيق أو
  بتسجيل الخروج.

## طلبات الإدارة

- **بحث الطلبات** `POST /api/admin/orders/search` — الجسم:
  `{ status?, page?, pageSize? (25/50/100), sort? }`، والرد:
  `{ orders[], total, page, pageSize, totalPages, bucketCounts }`.
  كل طلب: `order_ref, created_at, total, status, payment_status,
  payment_method, governorate`. الحالات:
  `pending_transfer, paid, processing, shipped, delivered, cancelled`.
- **تفاصيل الطلب** `GET /api/admin/orders/{orderRef}` — الرد:
  `{ order, receipts, history }`؛ `order` فيه بيانات العميل والأصناف
  والمبالغ وحالة الدفع و`receiptAvailable`.
- **تغيير الحالة** `PATCH /api/orders/{orderRef}/status` — الجسم:
  `{ status, reason? }`، والسبب إلزامي عند الإلغاء. الانتقالات
  المسموحة: `pending_transfer → paid/cancelled`، `paid → processing/
  cancelled`، `processing → shipped/cancelled`، `shipped → delivered`،
  `cancelled → pending_transfer`. الانتقال إلى `processing` أو `shipped`
  يتطلب دفعاً موثقاً (`payment_status = verified`)، والانتقال إلى `paid`
  يوثّق الدفع تلقائياً.
- **مراجعة الدفع** `PATCH /api/orders/{orderRef}/payment` — الجسم:
  `{ paymentStatus, reason?, manualConfirmation? }`. الانتقالات:
  `unpaid → verified`، `proof_submitted → verified/rejected`،
  `rejected → verified`، `verified → refunded`. توثيق دفع بلا إثبات
  مرفوع يتطلب `manualConfirmation: true` وسبباً من 5 أحرف على الأقل.

## الإشعارات الفورية (FCM)

يطبّق التطبيق (`lib/services/push_service.dart`) طرف العميل كاملاً:
تهيئة Firebase، وطلب الإذن، ورمز FCM، وعرض الرسائل الواردة (في
المقدمة والخلفية) عبر إشعارات محلية، والاشتراك في المواضيع
`zakham_orders` (تحديثات الطلبات)، و`zakham_offers` (العروض)،
و`zakham_new` (وصل حديثاً)، مع صفحة إعدادات (`حسابي ← الإشعارات`)
فيها زر اختبار وعرض رمز الجهاز.

التفعيل يحتاج خطوتين خارج المستودع:

1. **ملفات Firebase** (من مشروع Firebase الخاص بالدار — مشروع
   `zakham-f4b6e`):
   `android/app/google-services.json` و`ios/Runner/GoogleService-Info.plist`
   (حزمة أندرويد `com.houseofzakham.house_of_zakham`، ومعرّف آيفون
   `com.houseofzakham.houseofzakham` — بلا شرطات سفلية، لأن Firebase
   وآبل يرفضانها في معرّف الحزمة). بدونها يبقى
   `PushService.available = false` ويعمل التطبيق طبيعياً دون إشعارات.
2. **مرسِل الخادم**: نقطة إرسال FCM على المتجر تستقبل رموز الأجهزة
   وترسل تحديثات حالة الطلبات — غير موجودة بعد في `api.php`، وهي
   خطوة خادم مستقلة (تحتاج مفتاح خدمة Firebase).

## ترويسات Flutter للمصادقة وCSRF

تستخدم طبقة `lib/services/api_headers.dart` ترويسات موحدة:

```text
Cookie: PHPSESSID=<session id>
X-CSRF-Token: <server-issued csrf token>
```

يتم إرسال `Cookie` مع كل طلب إداري، و`X-CSRF-Token` مع الطلبات
المعدِّلة مثل `PATCH` و`DELETE` و`POST`. الجلسة ورمز CSRF يبقيان في
الذاكرة فقط ولا يتم حفظهما في `SharedPreferences` أو طباعتهما في
السجلات.

مثال الاستخدام:

```dart
final api = AdminApi();
await api.login(email: email, password: password);
await api.analytics();
await api.orders(status: 'pending_transfer');
await api.logout();
```
