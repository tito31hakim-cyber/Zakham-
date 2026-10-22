# تكامل API — House of Zakham

تمت إضافة:

- `lib/models/product.dart`: يحول JSON المنتج إلى نموذج Flutter.
- `lib/services/product_api.dart`: يجلب قائمة المنتجات من `GET /products`.

## تصحيح JSON المرسل

القيمة الصحيحة لحقل `base_notes` يجب أن تكون:

```json
"base_notes": ["العود", "المسك", "العنبر"]
```

وليس:

```json
"base_notes": ["العود", "المسك", العنبر]
```

## الاستخدام بعد معرفة الرابط

```dart
final api = ProductApi(
  baseUrl: 'https://YOUR-DOMAIN.example/api',
);

final products = await api.fetchProducts();
```

إذا كان الرد مغلفًا، فالعميل يدعم الشكلين:

```json
[
  { "product_id": "1" }
]
```

أو:

```json
{
  "data": [
    { "product_id": "1" }
  ]
}
```

## المطلوب لإكمال الربط

- عنوان Endpoint الحقيقي.
- هل المسار هو `/products` أم مسار آخر؟
- عنوان الصور الكامل إذا كانت قيمة `image` نسبية مثل `assets/...`.
- هل الـ API يحتاج Token؟
- مثال حقيقي للرد، ويفضل أن يحتوي على أكثر من منتج.
