import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/mt_app.dart';
import 'core/api_config.dart';
import 'core/trading_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pehli paint pehle — SharedPreferences/network await mat karo,
  // warna splash pe APK stuck / bohot slow lagta hai.
  _applySystemUi();
  runApp(const MtApp());
  unawaited(_bootstrapAfterFirstFrame());
}

void _applySystemUi() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

Future<void> _bootstrapAfterFirstFrame() async {
  // Ek frame paint hone do, phir disk + network.
  await Future<void>.delayed(Duration.zero);
  await Future.wait([
    ApiConfig.load(),
    tradingService.restoreLocal(),
  ]);
  unawaited(tradingService.bootstrapNetwork());
}
