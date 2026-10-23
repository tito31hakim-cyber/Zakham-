# تكامل API — House of Zakham

## الاستضافة

النسخة الحالية من الخلفية مستضافة على Infinity Free وتستخدم `api.php` مع قواعد إعادة الكتابة الموجودة في `.htaccess`.

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

يرد `/api/storefront` بالشكل التالي:

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
      "season": "وصف العطر",
      "notes": {
        "top": "نفحات البداية",
        "middle": "قلب العطر",
        "base": "القاعدة"
      },
      "prices": {"30": 250, "50": 350, "100": 500},
      "variants": {
        "presence": {
          "label": "حُضور · Eau de Parfum",
          "prices": {"30": 250, "50": 350, "100": 500}
        }
      },
      "stockQty": 10,
      "stockStatus": "available"
    }
  ]
}
```

يتولى `Product.fromJson` تحويل صيغ الاستضافة إلى نموذج Flutter، بما في ذلك:

- `notes.top/middle/base`.
- `prices` و`variants`.
- `stockQty` و`stockStatus`.
- الصور النسبية تحت `/assets/products/`.

## الطلبات

يرسل تطبيق Flutter الطلبات إلى `/api/orders` باستخدام JSON. الخادم الحالي يقبل بيانات العميل والعناصر والمجموع والإجمالي، لذلك يجب أن تبقى إعادة حساب الأسعار والإجمالي على الخادم قبل اعتماد الطلب في بيئة الإنتاج.

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
