import '../config/app_config.dart';
import '../models/product.dart';

const featuredProduct = Product(
  id: 'zakham-royal',
  name: 'زَخَم رويال',
  price: 500,
  currency: 'EGP',
  size: '100 ml',
  category: 'royal',
  topNotes: ['الزعفران', 'البرغموت'],
  heartNotes: ['الورد', 'العنبر'],
  baseNotes: ['العود', 'المسك'],
  image: AppConfig.featuredImage,
  inStock: true,
);
