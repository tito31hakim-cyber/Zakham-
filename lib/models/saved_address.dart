/// عنوان محفوظ في حساب العميل (بيت/شغل/أخرى).
///
/// يُخزَّن على الخادم عند توفر نقطة `/api/account/addresses`، وإلا
/// محلياً في SharedPreferences — والتطبيق لا يفرّق بينهما في العرض.
/// المدينة نص حر في الحفظ؛ أما في إتمام الطلب فتُعرض كقائمة منسدلة
/// من `/api/locations/eg` عندما تتوفر (وهي القائمة المعتمدة لدى
/// الخادم)، وإلا حقل نصي.
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.governorate,
    required this.city,
    required this.street,
    required this.phone,
    this.isDefault = false,
  });

  /// معرّف الخادم (رقم) أو معرّف محلي (`local_<millis>_<rand>`).
  final String id;

  /// بيت / شغل / أخرى.
  final String label;
  final String governorate;
  final String city;

  /// الشارع ورقم المبنى وعلامة مميزة.
  final String street;

  /// هاتف التواصل لهذا العنوان.
  final String phone;

  /// عنوان واحد فقط افتراضي لكل حساب.
  final bool isDefault;

  String get displayTitle => '$label — $governorate';
  String get displayLine =>
      city.isEmpty ? street : '$city، $street';

  /// الحقول كما تُرسل إلى الخادم (label/governorate/city/street/phone).
  Map<String, dynamic> toRequestJson() => {
        'label': label,
        'governorate': governorate,
        'city': city,
        'street': street,
        'phone': phone,
        'isDefault': isDefault,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        ...toRequestJson(),
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: '${json['id'] ?? ''}',
        label: '${json['label'] ?? 'أخرى'}',
        governorate: '${json['governorate'] ?? ''}',
        city: '${json['city'] ?? ''}',
        street: '${json['street'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        isDefault: json['isDefault'] == true || json['is_default'] == 1,
      );

  SavedAddress copyWith({
    String? id,
    String? label,
    String? governorate,
    String? city,
    String? street,
    String? phone,
    bool? isDefault,
  }) =>
      SavedAddress(
        id: id ?? this.id,
        label: label ?? this.label,
        governorate: governorate ?? this.governorate,
        city: city ?? this.city,
        street: street ?? this.street,
        phone: phone ?? this.phone,
        isDefault: isDefault ?? this.isDefault,
      );

  /// الحقول كما تُعبَّأ في نموذج إتمام الطلب بضغطة واحدة.
  Map<String, String> get checkoutFields => {
        'governorate': governorate,
        'city': city,
        'street': street,
        'phone': phone,
      };
}

/// تسميات العناوين المتاحة.
const List<String> addressLabels = <String>['بيت', 'شغل', 'أخرى'];

/// المحافظات الـ27 كما في إتمام الطلب — تُستخدم كبديل عند غياب
/// قائمة المحافظات المعتمدة من الخادم (GET /api/locations/eg).
const List<String> egyptGovernorates = <String>[
  'القاهرة',
  'الجيزة',
  'الإسكندرية',
  'القليوبية',
  'الدقهلية',
  'البحر الأحمر',
  'البحيرة',
  'الفيوم',
  'الغربية',
  'الإسماعيلية',
  'المنوفية',
  'المنيا',
  'أسيوط',
  'الوادي الجديد',
  'بني سويف',
  'بورسعيد',
  'دمياط',
  'جنوب سيناء',
  'كفر الشيخ',
  'مطروح',
  'الأقصر',
  'قنا',
  'شمال سيناء',
  'سوهاج',
  'السويس',
  'أسوان',
  'الشرقية',
];
