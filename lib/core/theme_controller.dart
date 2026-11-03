import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mt_colors.dart';
import '../ui/theme/oceana_colors.dart';

/// false = white theme, true = black theme.
final ValueNotifier<bool> mtDarkMode = ValueNotifier<bool>(false);

void setMtDarkMode(bool dark) {
  OcColors.applyDark(dark);
  MtColors.applyDark(dark);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: dark ? const Color(0xFF0E0E10) : Colors.white,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.black,
    ),
  );
  mtDarkMode.value = dark;
}
