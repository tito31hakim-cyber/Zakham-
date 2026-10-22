import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/main.dart';

void main() {
  testWidgets('House of Zakham home renders', (tester) async {
    await tester.pumpWidget(const ZakhamApp());
    expect(find.text('زَخَم'), findsOneWidget);
    expect(find.text('أثر يبقى.'), findsOneWidget);
    expect(find.text('اعثر على عطرك'), findsOneWidget);
  });
}
