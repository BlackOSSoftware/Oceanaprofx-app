import 'package:flutter/material.dart';

import '../icons/oc_icons.dart';
import '../theme/oceana_colors.dart';

enum OcNavTab { quote, chart, trade, dashboard, more }

class OcBottomNav extends StatelessWidget {
  const OcBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final OcNavTab current;
  final ValueChanged<OcNavTab> onSelect;

  /// Floating pill height (icon + label + inner padding), excluding outer inset.
  static const double pillHeight = 56;

  /// Body bottom gap so content clears the floating nav (`extendBody: true`).
  static double bodyClearance(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    const outerBottom = 8.0;
    final inset = safe > 0 ? safe : 6.0;
    return pillHeight + outerBottom + inset;
  }

  static const _items = <(OcNavTab, IconData, String, int)>[
    (OcNavTab.quote, OcIcons.lineChart, 'Quote', 10),
    (OcNavTab.chart, OcIcons.barChart3, 'Chart', 10),
    (OcNavTab.trade, OcIcons.candlestickChart, 'Trade', 10),
    // Extra flex so "Dashboard" label + active chip fully fit.
    (OcNavTab.dashboard, OcIcons.wallet, 'Dashboard', 14),
    (OcNavTab.more, OcIcons.settings, 'More', 10),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + (bottom > 0 ? bottom : 6)),
      child: Material(
        color: OcColors.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: OcColors.isDark ? 0.45 : 0.18),
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: pillHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: OcColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final item in _items)
                Expanded(
                  flex: item.$4,
                  child: _NavItem(
                    icon: item.$2,
                    label: item.$3,
                    selected: current == item.$1,
                    onTap: () => onSelect(item.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? OcColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? OcColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 14,
                    color: selected ? Colors.white : OcColors.navInactive,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? OcColors.primary : OcColors.navInactive,
                      height: 1.0,
                      letterSpacing: -0.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
