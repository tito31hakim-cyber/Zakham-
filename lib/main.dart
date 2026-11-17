import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/cart_provider.dart';
import 'providers/customer_provider.dart';
import 'services/push_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Push init is best-effort and never blocks startup: without the
  // Firebase project files the service reports unavailable and the app
  // keeps working normally.
  unawaited(PushService.instance.init());
  final customerProvider = CustomerProvider();
  // Restoring the member session is best-effort too: a dead cookie just
  // means "signed out" and the app keeps working as a guest.
  unawaited(customerProvider.init());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider.value(value: customerProvider),
      ],
      child: const ZakhamApp(),
    ),
  );
}
