import 'package:flutter/material.dart';

import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// TradingView chart style codes for Advanced Chart widget `style`.
class ChartStyleOption {
  const ChartStyleOption({
    required this.code,
    required this.label,
    required this.icon,
  });

  final String code;
  final String label;
  final IconData icon;

  static const all = <ChartStyleOption>[
    ChartStyleOption(
      code: '1',
      label: 'Candles',
      icon: OcIcons.candlestickChart,
    ),
    ChartStyleOption(
      code: '0',
      label: 'Bars',
      icon: OcIcons.barChart3,
    ),
    ChartStyleOption(
      code: '2',
      label: 'Line',
      icon: OcIcons.lineChart,
    ),
    ChartStyleOption(
      code: '3',
      label: 'Area',
      icon: OcIcons.lineChart,
    ),
    ChartStyleOption(
      code: '8',
      label: 'Heikin Ashi',
      icon: OcIcons.candlestickChart,
    ),
    ChartStyleOption(
      code: '9',
      label: 'Hollow candles',
      icon: OcIcons.candlestickChart,
    ),
  ];
}

Future<String?> showOceanaChartStyleSheet(
  BuildContext context, {
  required String selected,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Chart style',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, a1, a2) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 108, 12, 0),
            child: Material(
              color: OcColors.surface,
              elevation: 8,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 4, 10, 8),
                      child: Text(
                        'Chart type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final opt in ChartStyleOption.all)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          opt.icon,
                          size: 20,
                          color: selected == opt.code
                              ? OcColors.primary
                              : OcColors.textSecondary,
                        ),
                        title: Text(
                          opt.label,
                          style: TextStyle(
                            fontWeight: selected == opt.code
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected == opt.code
                                ? OcColors.primary
                                : OcColors.text,
                          ),
                        ),
                        trailing: selected == opt.code
                            ? const Icon(
                                OcIcons.checkCircle2,
                                size: 18,
                                color: OcColors.primary,
                              )
                            : null,
                        onTap: () => Navigator.pop(ctx, opt.code),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
