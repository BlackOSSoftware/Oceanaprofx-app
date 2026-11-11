import 'package:flutter/material.dart';

import '../core/app_update/app_update_gate.dart';
import '../core/theme_controller.dart';
import '../core/trading_service.dart';
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        tradingService.onAppResumed();
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        tradingService.onAppBackgrounded();
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
              title: 'OceanaProFx',
              debugShowCheckedModeBanner: false,
              theme: OceanaTheme.light,
              darkTheme: OceanaTheme.dark,
              themeMode: mtThemeModeForApp(),
              scrollBehavior: const OceanaScrollBehavior(),
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                // Slight global bump (~7%) — covers theme + hardcoded fontSizes.
                final system = mq.textScaler.scale(1.0);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: TextScaler.linear(system * 1.07),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
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
