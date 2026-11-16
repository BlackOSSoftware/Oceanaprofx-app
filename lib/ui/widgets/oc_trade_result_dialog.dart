import 'package:flutter/material.dart';

import '../icons/oc_icons.dart';
import '../theme/oceana_colors.dart';

/// Small floating trade alert — top of screen (not over Buy/Sell buttons).
Future<void> showOcTradeResult(
  BuildContext context, {
  required String title,
  required String message,
  bool success = true,
  Duration duration = const Duration(milliseconds: 1600),
}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;
  var closed = false;

  void close() {
    if (closed) return;
    closed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final accent = success ? OcColors.ask : OcColors.loss;
      final soft = success ? OcColors.depositBg : OcColors.withdrawBg;
      final top = MediaQuery.paddingOf(ctx).top;
      return Positioned(
        left: 16,
        right: 16,
        // Chart header area — never over bottom trade buttons / nav.
        top: top + 52,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, -8 * (1 - t)),
                child: child,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: OcColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OcColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: soft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        success ? OcIcons.checkCircle2 : OcIcons.xCircle,
                        color: accent,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: OcColors.text,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: OcColors.textSecondary,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: close,
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: Icon(
                        OcIcons.x,
                        size: 18,
                        color: OcColors.textMuted,
                      ),
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

  overlay.insert(entry);
  await Future<void>.delayed(duration);
  close();
}
