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
  static const double pillHeight = 58;

  /// Body bottom gap so content clears the floating nav (`extendBody: true`).
  static double bodyClearance(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    const outerBottom = 8.0;
    final inset = safe > 0 ? safe : 6.0;
    return pillHeight + outerBottom + inset;
  }

  static const _items = <(OcNavTab, IconData, String)>[
    (OcNavTab.quote, OcIcons.lineChart, 'Quote'),
    (OcNavTab.chart, OcIcons.barChart3, 'Chart'),
    (OcNavTab.trade, OcIcons.candlestickChart, 'Trade'),
    (OcNavTab.dashboard, OcIcons.wallet, 'Dashboard'),
    (OcNavTab.more, OcIcons.settings, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 8 + (bottom > 0 ? bottom : 6)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OcColors.surface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: OcColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: OcColors.isDark ? 0.35 : 0.10),
              blurRadius: 22,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: OcColors.isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
          child: Row(
            children: [
              for (final item in _items)
                Expanded(
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? OcColors.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? OcColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : OcColors.navInactive,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? OcColors.primary : OcColors.navInactive,
                  height: 1.05,
                  letterSpacing: -0.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
