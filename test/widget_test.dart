import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_of_zakham/app.dart';

void main() {
  testWidgets('Dar Zakham home renders brand mark', (tester) async {
    await tester.pumpWidget(const ZakhamApp());
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/brand/zakham-brand-mark.png',
      ),
      findsOneWidget,
    );
    expect(find.byType(BottomNavigationBar), findsNothing);
  });
}
