import 'package:flutter/material.dart';

import '../format.dart';
import '../mt_colors.dart';
import '../trading_service.dart';

class MtBottomNav extends StatelessWidget {
  MtBottomNav({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static final _labels = ['Quotes', 'Charts', 'Trade', 'History', 'Messages'];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MtColors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            // Sirf Trade PnL ke liye suno — har WS tick pe pura nav mat
            // rebuild (release open / jank kam).
            child: ListenableBuilder(
              listenable: tradingService,
              builder: (context, _) {
                final pnl = _tradeFloatingPnl();
                return Row(
                  children: [
                    for (var i = 0; i < _labels.length; i++)
                      Expanded(
                        child: _NavItem(
                          label: _labels[i],
                          selected: i == index,
                          icon: _icon(
                            i,
                            i == index ? MtColors.accent : MtColors.icon,
                          ),
                          tradePnl: i == 2 ? pnl : null,
                          onTap: () => onChanged(i),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Open positions ka total floating PnL — null agar koi position nahi.
  double? _tradeFloatingPnl() {
    if (tradingService.positions.isEmpty) return null;
    var sum = 0.0;
    for (final p in tradingService.positions.values) {
      sum += p.floatingPnL;
    }
    return sum;
  }

  Widget _icon(int i, Color color) {
    if (i == 0) {
      return _assetIcon('assets/icons/quotes_arrows.png', color, size: 20);
    }
    if (i == 1) {
      return _assetIcon('assets/icons/trade_candles.png', color);
    }
    if (i == 2) {
      return TradeNavIcon(color: color);
    }
    if (i == 3) {
      return Transform.rotate(
        angle: 2 / 13,
        child: Icon(Icons.history, size: 26, color: color),
      );
    }
    if (i == 4) {
      return _assetIcon('assets/icons/messages_bubbles.png', color);
    }
    const icons = [
      Icons.swap_vert,
      Icons.candlestick_chart,
      Icons.show_chart,
      Icons.history,
      Icons.forum_outlined,
    ];
    return Icon(icons[i], size: 26, color: color);
  }

  Widget _assetIcon(String asset, Color color, {double size = 26}) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
    );
  }
}

class TradeNavIcon extends StatelessWidget {
  const TradeNavIcon({super.key, required this.color, this.size = 26});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TradeIconPainter(color),
    );
  }
}

class _TradeIconPainter extends CustomPainter {
  const _TradeIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = color;
    const points = <Offset>[
      Offset(4.9, 18.3),
      Offset(10.6, 10.7),
      Offset(15.1, 14.5),
      Offset(21.2, 6.9),
    ];
    canvas.drawPath(Path()..addPolygon(points, false), line);
    const radii = <double>[2.6, 1.7, 1.7, 2.6];
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], radii[i], dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TradeIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _NavItem extends StatelessWidget {
  _NavItem({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.tradePnl,
  });

  final String label;
  final bool selected;
  final Widget icon;
  final VoidCallback onTap;
  final double? tradePnl;

  @override
  Widget build(BuildContext context) {
    final color = selected ? MtColors.accent : MtColors.icon;
    final showPnl = tradePnl != null;
    final profit = (tradePnl ?? 0) >= 0;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 2),
          if (showPnl)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
              decoration: BoxDecoration(
                color: profit
                    ? const Color(0xFFE3F0FF)
                    : const Color(0xFFFCE4E4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                formatMoney(tradePnl!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: profit ? MtColors.bid : MtColors.ask,
                  fontFamily: 'Roboto',
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'Roboto',
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
