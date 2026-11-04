import 'package:flutter/material.dart';

import '../core/app_update/app_update_gate.dart';
import '../core/theme_controller.dart';
import '../features/shell/oceana_shell.dart';
import '../ui/theme/oceana_theme.dart';

class OceanaApp extends StatefulWidget {
  const OceanaApp({super.key});

  @override
  State<OceanaApp> createState() => _OceanaAppState();
}

class _OceanaAppState extends State<OceanaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (mtThemePreference.value == MtThemePreference.system) {
      applyMtThemeFromPreference();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MtThemePreference>(
      valueListenable: mtThemePreference,
      builder: (context, pref, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: mtDarkMode,
          builder: (context, isDark, _) {
            return MaterialApp(
              title: 'Oceana',
              debugShowCheckedModeBanner: false,
              theme: OceanaTheme.light,
              darkTheme: OceanaTheme.dark,
              themeMode: mtThemeModeForApp(),
              scrollBehavior: const OceanaScrollBehavior(),
              home: AppUpdateGate(
                child: OceanaShell(key: ValueKey('$pref|$isDark')),
              ),
            );
          },
        );
      },
    );
  }
}
