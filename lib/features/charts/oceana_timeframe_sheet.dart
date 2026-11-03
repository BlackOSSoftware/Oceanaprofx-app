import 'package:flutter/material.dart';

import '../../ui/theme/oceana_colors.dart';

/// Screenshot timeframe panel — floats over chart (trade panel stays visible).
Future<String?> showOceanaTimeframeSheet(
  BuildContext context, {
  required String selected,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Timeframe',
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.42,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _section(ctx, 'MINUTES', selected, const [
                        ('M1', '1 minute'),
                        ('M5', '5 minutes'),
                        ('M15', '15 minutes'),
                        ('M30', '30 minutes'),
                      ]),
                      const SizedBox(height: 14),
                      _section(ctx, 'HOURS', selected, const [
                        ('H1', '1 hour'),
                        ('H2', '2 hours'),
                        ('H4', '4 hours'),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _section(
  BuildContext ctx,
  String title,
  String selected,
  List<(String, String)> items,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: OcColors.textMuted,
          letterSpacing: 0.6,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            Material(
              color: selected == item.$1
                  ? const Color(0xFF3A3A42)
                  : OcColors.bg,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => Navigator.pop(ctx, item.$1),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected == item.$1
                          ? Colors.white
                          : OcColors.text,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}
