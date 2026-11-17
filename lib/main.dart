import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/cart_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/theme_provider.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push init is best-effort and never blocks startup: without the
  // Firebase project files the service reports unavailable and the app
  // keeps working normally.
  unawaited(PushService.instance.init());
  final customerProvider = CustomerProvider();
  // Restoring the member session is best-effort too: a dead cookie just
  // means "signed out" and the app keeps working as a guest.
  unawaited(customerProvider.init());
  // The theme preference is awaited so the app never flashes the wrong
  // theme on startup.
  final themeProvider = ThemeProvider();
  await themeProvider.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider.value(value: customerProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const ZakhamApp(),
    ),
  );
}
