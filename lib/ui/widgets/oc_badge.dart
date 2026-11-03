import 'package:flutter/material.dart';

import '../theme/oceana_colors.dart';

class OcBadge extends StatelessWidget {
  const OcBadge({
    super.key,
    required this.label,
    this.filled = true,
    this.color,
    this.compact = false,
  });

  final String label;
  final bool filled;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = color ?? OcColors.primary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 1.5 : 2,
      ),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9.5 : 11,
          fontWeight: FontWeight.w700,
          color: filled ? Colors.white : c,
        ),
      ),
    );
  }
}
