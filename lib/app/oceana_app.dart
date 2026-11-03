import 'package:flutter/material.dart';

import '../core/app_update/app_update_gate.dart';
import '../core/theme_controller.dart';
import '../features/shell/oceana_shell.dart';
import '../ui/theme/oceana_theme.dart';

class OceanaApp extends StatelessWidget {
  const OceanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: mtDarkMode,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Oceana',
          debugShowCheckedModeBanner: false,
          theme: OceanaTheme.light,
          darkTheme: OceanaTheme.dark,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          scrollBehavior: const OceanaScrollBehavior(),
          home: AppUpdateGate(child: OceanaShell(key: ValueKey(isDark))),
        );
      },
    );
  }
}
