import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mt_colors.dart';
import '../ui/theme/oceana_colors.dart';

/// User theme choice — System follows phone light/dark.
enum MtThemePreference { system, light, dark }

const _prefsKey = 'mt_theme_preference_v1';

final ValueNotifier<MtThemePreference> mtThemePreference =
    ValueNotifier<MtThemePreference>(MtThemePreference.system);

/// Effective dark flag used by OcColors / MtColors / rebuilds.
final ValueNotifier<bool> mtDarkMode = ValueNotifier<bool>(false);

bool _loaded = false;

Future<void> loadMtThemePreference() async {
  if (_loaded) return;
  _loaded = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_prefsKey) ?? 'system').trim().toLowerCase();
    final pref = switch (raw) {
      'light' => MtThemePreference.light,
      'dark' => MtThemePreference.dark,
      _ => MtThemePreference.system,
    };
    mtThemePreference.value = pref;
  } catch (_) {
    mtThemePreference.value = MtThemePreference.system;
  }
  applyMtThemeFromPreference();
}

Future<void> setMtThemePreference(MtThemePreference pref) async {
  mtThemePreference.value = pref;
  applyMtThemeFromPreference();
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      switch (pref) {
        MtThemePreference.system => 'system',
        MtThemePreference.light => 'light',
        MtThemePreference.dark => 'dark',
      },
    );
  } catch (_) {}
}

/// Legacy helper — maps to light/dark (keeps older call sites working).
void setMtDarkMode(bool dark) {
  setMtThemePreference(
    dark ? MtThemePreference.dark : MtThemePreference.light,
  );
}

bool platformBrightnessIsDark() {
  return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;
}

void applyMtThemeFromPreference() {
  final dark = switch (mtThemePreference.value) {
    MtThemePreference.system => platformBrightnessIsDark(),
    MtThemePreference.light => false,
    MtThemePreference.dark => true,
  };
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
  if (mtDarkMode.value != dark) {
    mtDarkMode.value = dark;
  }
}

ThemeMode mtThemeModeForApp() {
  return switch (mtThemePreference.value) {
    MtThemePreference.system => ThemeMode.system,
    MtThemePreference.light => ThemeMode.light,
    MtThemePreference.dark => ThemeMode.dark,
  };
}
