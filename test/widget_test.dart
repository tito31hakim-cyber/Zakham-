import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:house_of_zakham/app.dart';
import 'package:house_of_zakham/providers/cart_provider.dart';

void main() {
  testWidgets('Dar Zakham home renders brand mark', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartProvider(),
        child: const ZakhamApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
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
