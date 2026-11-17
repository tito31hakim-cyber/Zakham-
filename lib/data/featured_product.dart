import '../config/app_config.dart';
import '../models/product.dart';

/// المنتج المميز في الرئيسية — زَخَم رويال، مطابق لرد `/api/storefront` الحي.
///
/// ملاحظة: هذا احتياطي للعرض قبل تحميل الكتالوج فقط؛ التشكيلة الكاملة
/// (11 عطراً) تأتي دائماً من الخادم. أي تغيير في سعر رويال أو نوتاته
/// يجب أن يبدأ من لوحة إدارة المتجر ثم يُحدَّث هنا.
const featuredProduct = Product(
  id: 'royal',
  name: 'زَخَم رويال',
  nameEn: 'ZAKHAM ROYAL',
  price: 500,
  currency: 'EGP',
  size: '100 ml',
  category: 'official',
  categoryLabel: 'كتالوج زخم الرسمي 2027',
  topNotes: ['نفحات الكونياك المعتق، القرفة السيلانية الدافئة.'],
  heartNotes: ['حبوب التونكا، أخشاب البلوط، لمسات اللوز المر.'],
  baseNotes: ['الفانيليا المدغشقرية، حلوى البرالين، خشب الصندل، العنبر الملكي.'],
  image: AppConfig.featuredImage,
  inStock: true,
  description: 'هيبة الملوك ونفحات القصور الفاخرة، صُمم لليالي الشتوية والمناسبات الرسمية الكبرى.',
  season: 'هيبة الملوك ونفحات القصور الفاخرة، صُمم لليالي الشتوية والمناسبات الرسمية الكبرى.',
  occasion: 'مناسبات رسمية',
  lasting: 'شتوي / مسائي',
  defaultConcentration: 'presence',
  prices: <String, dynamic>{'30': 250, '50': 350, '100': 500},
  variants: <String, dynamic>{
    'presence': <String, dynamic>{
      'label': 'حُضور · Eau de Parfum',
      'labelEn': 'Eau de Parfum',
      'prices': <String, dynamic>{'30': 250, '50': 350, '100': 500},
    },
    'extra': <String, dynamic>{
      'label': 'فَوْحان · Extrait Prime Parfum',
      'labelEn': 'Extrait Prime Parfum',
      'prices': <String, dynamic>{'30': 350, '50': 500, '100': 700},
    },
    'nuclear': <String, dynamic>{
      'label': 'نووي · Extrait Max Parfum',
      'labelEn': 'Extrait Max Parfum',
      'prices': <String, dynamic>{'50': 650, '100': 950},
    },
  },
);
