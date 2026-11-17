import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/cart_provider.dart';
import 'services/push_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Push init is best-effort and never blocks startup: without the
  // Firebase project files the service reports unavailable and the app
  // keeps working normally.
  unawaited(PushService.instance.init());
  runApp(
    ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: const ZakhamApp(),
    ),
  );
}
