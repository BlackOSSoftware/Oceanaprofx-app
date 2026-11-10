import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/trading_service.dart';
import '../../ui/theme/oceana_colors.dart';
import 'chart_controller.dart';
import 'chart_models.dart';
import 'chart_painter.dart';

/// Native candlestick chart fed by `/v1/chart/candles` + live broker ticks.
/// Last candle / bid-ask lines track [tradingService] quotes (same as Quotes).
class OceanaBrokerChart extends StatefulWidget {
  const OceanaBrokerChart({
    super.key,
    required this.symbol,
    required this.timeframe,
    this.active = true,
  });

  final String symbol;
  final ChartTimeframe timeframe;
  final bool active;

  @override
  State<OceanaBrokerChart> createState() => _OceanaBrokerChartState();
}

class _OceanaBrokerChartState extends State<OceanaBrokerChart> {
  final _ctrl = ChartController();
  double _spacing = 9;
  double _scroll = 0;
  double _startSpacing = 9;
  double _startScroll = 0;
  Offset _startFocal = Offset.zero;
  double _vZoom = 1;
  double _startVZoom = 1;
  bool _axisDrag = false;
  bool _timeAxisDrag = false;
  Size _chartSize = Size.zero;
  int _revision = 0;
  Offset? _cross;

  @override
  void initState() {
    super.initState();
    tradingService.ensureSubscribed(widget.symbol);
    tradingService.addListener(_onLive);
    _ctrl.addListener(_onCtrl);
    _ctrl.setVisible(widget.active);
    _ctrl.load(widget.symbol, widget.timeframe);
  }

  @override
  void didUpdateWidget(covariant OceanaBrokerChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      tradingService.ensureSubscribed(widget.symbol);
      _resetView();
      _ctrl.load(widget.symbol, widget.timeframe);
    } else if (oldWidget.timeframe.code != widget.timeframe.code) {
      _resetView();
      _ctrl.load(widget.symbol, widget.timeframe);
    }
    if (oldWidget.active != widget.active) {
      _ctrl.setVisible(widget.active);
    }
  }

  @override
  void dispose() {
    tradingService.removeListener(_onLive);
    _ctrl
      ..removeListener(_onCtrl)
      ..dispose();
    super.dispose();
  }

  void _resetView() {
    _scroll = 0;
    _cross = null;
    _revision = 0;
  }

  void _onCtrl() {
    // Align forming candle to live broker bid as soon as history arrives.
    if (!_ctrl.loading && _ctrl.candles.isNotEmpty) {
      final q = tradingService.quoteFor(widget.symbol);
      if (q != null && q.hasPrice) {
        if (_ctrl.onTick(q.bid, q.time ?? DateTime.now())) _revision++;
      }
    }
    if (mounted && widget.active) setState(() {});
  }

  void _onLive() {
    if (!mounted || !widget.active) return;
    final q = tradingService.quoteFor(widget.symbol);
    if (q == null || !q.hasPrice) return;
    // Mid tracks what traders see as "the" mark; candle close follows bid
    // (same as Quotes / MT5 chart) so OHLC stays consistent with bid line.
    if (_ctrl.onTick(q.bid, q.time ?? DateTime.now())) {
      _revision++;
    }
    setState(() {});
  }

  ChartLayout get _layout => ChartLayout(
        size: _chartSize,
        count: _ctrl.candles.length,
        spacing: _spacing,
        scroll: _scroll,
      );

  double _clampScroll(double s) {
    final n = _ctrl.candles.length;
    final visible = _layout.plotWidth / math.max(_spacing, 1);
    final minS = -math.max(0.0, visible / 2 - ChartLayout.rightMargin);
    final maxS = math.max(0.0, n - 5.0);
    return s.clamp(minS, maxS);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startSpacing = _spacing;
    _startScroll = _scroll;
    _startFocal = d.localFocalPoint;
    _startVZoom = _vZoom;
    _axisDrag = d.pointerCount == 1 && d.localFocalPoint.dx > _layout.plotWidth;
    _timeAxisDrag = !_axisDrag &&
        d.pointerCount == 1 &&
        d.localFocalPoint.dy > _layout.plotBottom;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_axisDrag) {
      final dy = d.localFocalPoint.dy - _startFocal.dy;
      setState(() {
        _vZoom = (_startVZoom * math.exp(dy / 180)).clamp(0.15, 8.0);
      });
      return;
    }
    if (_timeAxisDrag) {
      final dx = d.localFocalPoint.dx - _startFocal.dx;
      setState(() {
        _spacing = (_startSpacing * math.exp(dx / 160)).clamp(2.0, 40.0);
        _scroll = _clampScroll(_scroll);
      });
      final (first, _) = _layout.visibleRange;
      if (first < 30) _ctrl.loadOlder();
      return;
    }
    setState(() {
      _spacing = (_startSpacing * d.horizontalScale).clamp(2.0, 40.0);
      final dx = d.localFocalPoint.dx - _startFocal.dx;
      _scroll = _clampScroll(_startScroll + dx / _spacing);
      _cross = d.localFocalPoint;
    });
    final (first, _) = _layout.visibleRange;
    if (first < 30) _ctrl.loadOlder();
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _axisDrag = false;
    _timeAxisDrag = false;
  }

  @override
  Widget build(BuildContext context) {
    final q = tradingService.quoteFor(widget.symbol);
    final digits = _ctrl.digits ?? q?.digits ?? 5;
    final candles = _ctrl.candles;

    return ColoredBox(
      color: OcColors.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                _chartSize = box.biggest;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: _onScaleEnd,
                  onTapUp: (d) => setState(() => _cross = d.localPosition),
                  child: CustomPaint(
                    size: box.biggest,
                    painter: ChartPainter(
                      vZoom: _vZoom,
                      candles: candles,
                      timeframe: widget.timeframe,
                      digits: digits,
                      spacing: _spacing,
                      scroll: _scroll,
                      bid: q != null && q.hasPrice ? q.bid : null,
                      ask: q != null && q.hasPrice ? q.ask : null,
                      secondsLeft: _ctrl.secondsLeft,
                      crosshair: _cross,
                      revision: _revision,
                    ),
                  ),
                );
              },
            ),
          ),
          if (_ctrl.loading)
            Positioned(
              top: 8,
              left: 0,
              right: ChartLayout.axisWidth,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OcColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading chart…',
                      style: TextStyle(
                        fontSize: 13,
                        color: OcColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_ctrl.loadingMore)
            Positioned(
              left: 8,
              top: 70,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: OcColors.primary,
                ),
              ),
            ),
          if (_ctrl.error != null && candles.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _ctrl.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OcColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: _ctrl.reload,
                      child: Text(
                        'Retry',
                        style: TextStyle(color: OcColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
