import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:house_of_zakham/app.dart';
import 'package:house_of_zakham/providers/cart_provider.dart';
import 'package:house_of_zakham/providers/discount_provider.dart';
import 'package:house_of_zakham/providers/theme_provider.dart';

void main() {
  testWidgets('House of Zakham home renders logo', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => DiscountProvider()),
        ],
        child: const ZakhamApp(),
      ),
    );
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
    expect(find.text('السلة'), findsOneWidget);
  });
}
