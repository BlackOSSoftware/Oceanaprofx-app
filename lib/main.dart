import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/oceana_app.dart';
import 'core/api_config.dart';
import 'core/push_notifications.dart';
import 'core/trading_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _applySystemUi();
  runApp(const OceanaApp());
  unawaited(_bootstrapAfterFirstFrame());
}

void _applySystemUi() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      // Phone system nav (back/home) — black even on white app theme.
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.black,
    ),
  );
}

Future<void> _bootstrapAfterFirstFrame() async {
  await Future<void>.delayed(Duration.zero);
  await Future.wait([
    ApiConfig.load(),
    tradingService.restoreLocal(),
  ]);
  unawaited(tradingService.bootstrapNetwork());
  // FCM after session restore so token can bind to portal user.
  unawaited(PushNotifications.init());
}
