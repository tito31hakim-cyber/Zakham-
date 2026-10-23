import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/main.dart';

void main() {
  testWidgets('House of Zakham home renders logo', (tester) async {
    await tester.pumpWidget(const ZakhamApp());
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/brand/zakham-house-logo.png',
      ),
      findsOneWidget,
    );
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}
