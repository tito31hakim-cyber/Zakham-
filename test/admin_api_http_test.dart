import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/services/admin_api.dart';

/// انحدار: `AdminApi._http` كان `‏_client ?? _http` — استدعاء ذاتي
/// لا نهائي (StackOverflow) عند إنشاء `AdminApi()` بلا عميل، أي في
/// الإنتاج كله. الإصلاح: `‏_client ?? SecureHttp.client`.
/// هذا الاختبار يثبت أن أول استدعاء شبكة بلا عميل يفشل بخطأ شبكة
/// عادي (مضيف غير موجود) لا بانهيار المكدس.
void main() {
  test('AdminApi() بلا عميل لا ينهار بالمكدس عند أول استدعاء', () async {
    final api = AdminApi(baseUrl: 'https://test.invalid');
    try {
      await api.fetchSession();
      fail('كان المتوقع فشل الشبكة نحو مضيف غير موجود');
    } catch (e) {
      expect(
        e.runtimeType.toString().contains('StackOverflow'),
        isFalse,
        reason: 'انهيار مكدس يعني أن _http ما زال يستدعي نفسه: $e',
      );
    }
  });
}
