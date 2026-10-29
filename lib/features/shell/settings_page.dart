import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../../core/mt_colors.dart';
import '../../core/theme_controller.dart';
import '../../core/trading_service.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MtColors.white,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: mtDarkMode,
        builder: (context, isDark, _) {
          return ListView(
            padding: EdgeInsets.only(top: 8),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Theme',
                  style: TextStyle(
                    color: MtColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: isDark,
                onChanged: (value) => setMtDarkMode(false),
                activeColor: MtColors.accent,
                title: Text(
                  'White theme',
                  style: TextStyle(color: MtColors.text, fontSize: 16),
                ),
              ),
              RadioListTile<bool>(
                value: true,
                groupValue: isDark,
                onChanged: (value) => setMtDarkMode(true),
                activeColor: MtColors.accent,
                title: Text(
                  'Black theme',
                  style: TextStyle(color: MtColors.text, fontSize: 16),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(
                  'Server',
                  style: TextStyle(
                    color: MtColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ListTile(
                title: Text(
                  'Trading server',
                  style: TextStyle(color: MtColors.text, fontSize: 16),
                ),
                subtitle: Text(
                  ApiConfig.publicServerLabel,
                  style: TextStyle(color: MtColors.textSecondary),
                ),
              ),
              ListTile(
                title: Text(
                  'Connection',
                  style: TextStyle(color: MtColors.text, fontSize: 16),
                ),
                subtitle: ListenableBuilder(
                  listenable: tradingService,
                  builder: (context, _) => Text(
                    tradingService.wsConnected
                        ? 'Connected'
                        : 'Connecting...',
                    style: TextStyle(
                      color: tradingService.wsConnected
                          ? MtColors.demo
                          : MtColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
