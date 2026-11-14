# تكامل API — House of Zakham

## الاستضافة

يستخدم التطبيق نطاق الفرع `zakhamhouse.shop` كمضيف للكتالوج والطلبات ولوحة الإدارة. يعتمد التنفيذ المنشور على `api.php` ومسارات API الخاصة بالنطاق؛ لا يُفترض أن استضافة هذا النطاق هي استضافة النطاق الأساسي `zakham.shop`.

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
| التحقق من رمز الإدارة | GET | `/api/analytics` مع `X-Admin-Token` |
| منتجات الإدارة | GET | `/api/admin/products` |
| تعديل منتج | PATCH | `/api/admin/products/{id}` |
| إخفاء منتج | DELETE | `/api/admin/products/{id}` |
| العملاء | GET | `/api/admin/customers?q=...` |
| بحث الطلبات الإدارية | POST | `/api/admin/orders/search` |
| تفاصيل طلب إداري | GET | `/api/admin/orders/{orderRef}` |

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

يرسل تطبيق Flutter الطلبات إلى `https://zakhamhouse.shop/api/orders` بصيغة `multipart/form-data` وبداخل الحقل `payload` كائن JSON، كما يفعل نموذج الموقع. يحتوي كل عنصر على `productId`, `sizeMl`, `concentration`, و`quantity`. ترسل بيانات العميل والمحافظة والعنوان الذي يتضمن المدينة وطريقة الدفع ومرجع التحويل والملاحظات ومفتاح منع التكرار ورمز التتبع. يقبل الموقع حاليًا `InstaPay | إنستاباي` و`Vodafone Cash | فودافون كاش` فقط؛ لا تُرسل طريقة دفع أخرى من التطبيق.

يجب أن يعيد الخادم الأسعار والإجمالي ورسوم الشحن من بياناته، لا أن يعتمد على مجموع يرسله العميل. صفحة الموقع تقرأ مرجع الطلب والإجمالي من الكائن `order` في الاستجابة، لذلك يدعم عميل Flutter الحقول المتداخلة `order.orderRef` و`order.total`.

## الإدارة

يستخدم تطبيق الهاتف طريقة المصادقة الأصلية للـAPI: يدخل المسؤول رمز الإدارة في التطبيق، ويرسله التطبيق في `X-Admin-Token` إلى استضافة الفرع. مسار `/api/admin/session` مرفوض من واجهة المتجر العامة (`403 admin_blocked_on_storefront`)، لذلك لا يُستخدم لتسجيل الدخول من التطبيق. قائمة الطلبات تستخدم `POST /api/admin/orders/search` وتفاصيل الطلب تستخدم `GET /api/admin/orders/{orderRef}` مع ترويسة الإدارة.

لا تضمّن رمز الإدارة في التطبيق أو المستودع؛ يبقى الرمز الذي يدخله المستخدم في ذاكرة التطبيق. يستخدم التطبيق النطاق الفرعي `zakhamhouse.shop` وفق اختيار المستخدم.

## ترويسات Flutter للمصادقة وCSRF

تستخدم طبقة إدارة التطبيق وعمليات المتجر الترويسات التالية عند الحاجة:

```text
Accept: application/json
Content-Type: application/json (للطلبات الإدارية التي ترسل JSON)
X-Admin-Token: <admin token entered by the administrator>
X-CSRF-Token: <server-issued csrf token>
```

يُرسل `X-CSRF-Token` إذا كان رمز CSRF متاحًا للعمليات المعدِّلة. لا تحفظ رموز الإدارة أو CSRF في `SharedPreferences` ولا تطبع في السجلات.

مثال الاستخدام:

```dart
final api = AdminApi(token: adminTokenHeldInMemory);
```

تحتاج عمليات التعديل إلى صلاحيات الإدارة التي يصدرها الخادم. لا يضمّن التطبيق رمزًا ثابتًا، ولا يخزن الرمز بعد إغلاقه.
