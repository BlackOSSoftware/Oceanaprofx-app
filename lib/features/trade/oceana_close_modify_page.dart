import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../charts/chart_indicators.dart';
import '../charts/chart_models.dart';
import '../charts/oceana_chart_style_sheet.dart';
import '../charts/oceana_indicator_sheet.dart';
import '../charts/oceana_timeframe_sheet.dart';
import '../charts/trading_view_chart.dart';
import '../quotes/symbol_flags.dart';

/// Close / Modify Position — Tenax SS layout, Oceana brand `#1414C7`.
class OceanaCloseModifyPage extends StatefulWidget {
  const OceanaCloseModifyPage({super.key, required this.position});

  final LivePosition position;

  static Future<void> open(BuildContext context, LivePosition position) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OceanaCloseModifyPage(position: position),
      ),
    );
  }

  @override
  State<OceanaCloseModifyPage> createState() => _OceanaCloseModifyPageState();
}

class _OceanaCloseModifyPageState extends State<OceanaCloseModifyPage> {
  static const _cardR = 12.0;
  static const _gap = 12.0;
  static Color get _pageBg => OcColors.bg;
  static const _cardBg = Color(0xFFF5F5F7);
  static const _cardLine = Color(0xFFE6E6EA);
  static const _lotStep = 0.01;

  late final String _positionId = widget.position.positionId;
  late int _volCents = (widget.position.volume * 100).round();
  double get _volume => _volCents / 100;
  int get _maxCents => math.max(1, (_pos.volume * 100).round());

  bool _partial = false;
  bool _showChart = false;
  bool _tpOn = false;
  bool _slOn = false;
  bool _busy = false;

  double? _tp;
  double? _sl;

  ChartTimeframe _tf = ChartTimeframes.of('M1');
  String _chartStyle = '1';
  final Set<String> _activeIndicators = {};

  List<String> get _studies => [
        for (final i in ChartIndicator.catalog)
          if (_activeIndicators.contains(i.id)) i.study,
      ];

  final _volumeCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  final _volumeFocus = FocusNode();
  final _tpFocus = FocusNode();
  final _slFocus = FocusNode();

  static final _qtyFormat = TextInputFormatter.withFunction((oldV, newV) {
    final t = newV.text;
    if (t.isEmpty) return newV;
    if (!RegExp(r'^(0|[1-9]\d{0,2})(\.\d{0,2})?$').hasMatch(t)) return oldV;
    return newV;
  });

  static final _priceFormat = TextInputFormatter.withFunction((oldV, newV) {
    final t = newV.text;
    if (t.isEmpty) return newV;
    if (!RegExp(r'^\d{0,8}(\.\d{0,5})?$').hasMatch(t)) return oldV;
    return newV;
  });

  LivePosition get _pos =>
      tradingService.positions[_positionId] ?? widget.position;

  String get _symbol => _pos.symbol;

  int get _digits {
    final q = tradingService.quoteFor(_symbol);
    return q?.digits ?? digitsFor(_symbol, _pos.openPrice);
  }

  double get _priceStep => math.pow(10, -_digits).toDouble();

  double _round(double v) {
    final f = math.pow(10, _digits).toDouble();
    return (v * f).round() / f;
  }

  double get _closePct =>
      _pos.volume <= 0 ? 0 : (_volume / _pos.volume * 100).clamp(0, 100);

  /// Pro-rata PnL for selected close volume.
  double get _closingPnL {
    if (_pos.volume <= 0) return 0;
    return _pos.floatingPnL * (_volume / _pos.volume);
  }

  @override
  void initState() {
    super.initState();
    _volumeCtrl.text = _volume.toStringAsFixed(2);
    final sl = _pos.stopLoss;
    final tp = _pos.takeProfit;
    if (sl != null && sl > 0) {
      _slOn = true;
      _sl = sl;
      _slCtrl.text = sl.toStringAsFixed(_digits);
    }
    if (tp != null && tp > 0) {
      _tpOn = true;
      _tp = tp;
      _tpCtrl.text = tp.toStringAsFixed(_digits);
    }
    tradingService.subscribe(_symbol);
    tradingService.addListener(_onTick);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onTick);
    _volumeCtrl.dispose();
    _tpCtrl.dispose();
    _slCtrl.dispose();
    _volumeFocus.dispose();
    _tpFocus.dispose();
    _slFocus.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted || _busy) return;
    if (!tradingService.positions.containsKey(_positionId)) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {});
  }

  void _unfocus() {
    _volumeFocus.unfocus();
    _tpFocus.unfocus();
    _slFocus.unfocus();
  }

  void _syncVolumeFromField() {
    final v = double.tryParse(_volumeCtrl.text.trim());
    final cents = v == null ? _volCents : (v * 100).round();
    setState(() {
      _volCents = cents.clamp(1, _maxCents);
      _volumeCtrl.text = _volume.toStringAsFixed(2);
    });
  }

  void _bumpVolume(double delta) {
    final next = ((_volCents + (delta * 100).round()).clamp(1, _maxCents));
    setState(() {
      _volCents = next;
      _volumeCtrl.text = _volume.toStringAsFixed(2);
    });
  }

  Future<void> _saveSlTpIfNeeded() async {
    final digits = _digits;
    double? parse(TextEditingController c, bool on) {
      if (!on) return null;
      final v = double.tryParse(c.text.trim());
      return v != null && v > 0 ? _round(v) : null;
    }

    final sl = parse(_slCtrl, _slOn);
    final tp = parse(_tpCtrl, _tpOn);
    _sl = sl;
    _tp = tp;

    final curSl = (_pos.stopLoss != null && _pos.stopLoss! > 0)
        ? _pos.stopLoss
        : null;
    final curTp = (_pos.takeProfit != null && _pos.takeProfit! > 0)
        ? _pos.takeProfit
        : null;
    bool same(double? a, double? b) {
      if (a == null && b == null) return true;
      if (a == null || b == null) return false;
      return (a - b).abs() < math.pow(10, -digits) / 2;
    }

    if (same(sl, curSl) && same(tp, curTp)) return;
    await tradingService.modifyPosition(
      positionId: _positionId,
      stopLoss: sl,
      takeProfit: tp,
    );
  }

  Future<void> _submitClose() async {
    _unfocus();
    if (_partial) _syncVolumeFromField();
    if (_volCents < _maxCents) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partial close is not supported yet')),
      );
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    try {
      await _saveSlTpIfNeeded();
      await tradingService.closePosition(_positionId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pos;
    final pnl = _closingPnL;
    final profit = pnl >= 0;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            _header(p),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 16 + bottomInset),
                children: [
                  _LiveBidAskCard(symbol: _symbol),
                  SizedBox(height: _gap),
                  _chartToggle(),
                  if (_showChart) ...[
                    SizedBox(height: 8),
                    _chartBlock(),
                  ],
                  SizedBox(height: 16),
                  Text(
                    'Close Partially',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: OcColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _switchCard(
                    label: 'Partial Close',
                    value: _partial,
                    onChanged: (v) {
                      _unfocus();
                      setState(() {
                        _partial = v;
                        if (!v) {
                          _volCents = _maxCents;
                          _volumeCtrl.text = _volume.toStringAsFixed(2);
                        }
                      });
                    },
                  ),
                  if (_partial) ...[
                    const SizedBox(height: 8),
                    _volumeStepper(),
                  ],
                  const SizedBox(height: 8),
                  _selectedBanner(),
                  const SizedBox(height: _gap),
                  _tpSlCard(),
                  const SizedBox(height: _gap),
                  _pnlCard(pnl, profit),
                  const SizedBox(height: 14),
                  _closeButton(pnl, profit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(LivePosition p) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            visualDensity: VisualDensity.compact,
            icon: Icon(OcIcons.arrowBack, size: 22, color: OcColors.text),
          ),
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OcColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SymbolFlagPair(symbol: _symbol, size: 28),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Close / Modify Position',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: OcColors.text,
                    height: 1.15,
                  ),
                ),
                Text(
                  '${p.isBuy ? 'Buy' : 'Sell'} ${p.volume.toStringAsFixed(2)} $_symbol at ${_fmt(p.openPrice)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: OcColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v <= 0) return '—';
    return v.toStringAsFixed(_digits);
  }

  Widget _chartToggle() {
    return Container(
      height: 44,
      padding: EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_cardR),
        border: Border.all(color: _cardLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Chart',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: OcColors.text,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: _showChart,
              activeThumbColor: Colors.white,
              activeTrackColor: OcColors.primary,
              onChanged: (v) {
                _unfocus();
                setState(() => _showChart = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartBlock() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              InkWell(
                onTap: () async {
                  final p = await showOceanaTimeframeSheet(
                    context,
                    selected: _tf.code,
                  );
                  if (p != null) setState(() => _tf = ChartTimeframes.of(p));
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    _tf.code,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  final s = await showOceanaChartStyleSheet(
                    context,
                    selected: _chartStyle,
                  );
                  if (s != null) setState(() => _chartStyle = s);
                },
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(OcIcons.candlestickChart, size: 18),
                ),
              ),
              InkWell(
                onTap: () async {
                  await showOceanaIndicatorsSheet(
                    context,
                    activeIds: _activeIndicators,
                    onChanged: (ids) {
                      setState(() {
                        _activeIndicators
                          ..clear()
                          ..addAll(ids);
                      });
                    },
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Text(
                    'fx Indicators',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: OcColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OcColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: TradingViewChart(
            key: ValueKey(
              '$_symbol|${_tf.code}|$_chartStyle|${_studies.join(',')}',
            ),
            symbol: _symbol,
            interval: TradingViewChart.intervalFromCode(_tf.code),
            style: _chartStyle,
            studies: _studies,
          ),
        ),
      ],
    );
  }

  Widget _switchCard({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 48,
      padding: EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_cardR),
        border: Border.all(color: _cardLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: OcColors.text,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: OcColors.primary,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _volumeStepper() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_cardR),
        border: Border.all(color: _cardLine),
      ),
      child: Row(
        children: [
          _stepBtn(Icons.remove, () => _bumpVolume(-_lotStep)),
          Expanded(
            child: TextField(
              controller: _volumeCtrl,
              focusNode: _volumeFocus,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_qtyFormat],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onEditingComplete: _syncVolumeFromField,
            ),
          ),
          _stepBtn(Icons.add, () => _bumpVolume(_lotStep)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, size: 20, color: OcColors.textSecondary),
      ),
    );
  }

  Widget _selectedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: OcColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OcColors.primary.withValues(alpha: 0.45)),
      ),
      child: Text(
        'Selected: ${_volume.toStringAsFixed(2)} lots (${_closePct.toStringAsFixed(1)}%)',
        style: const TextStyle(
          color: OcColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
      ),
    );
  }

  Widget _tpSlCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_cardR),
        border: Border.all(color: _cardLine),
      ),
      child: Column(
        children: [
          _tpSlRow(
            label: 'Take Profit',
            on: _tpOn,
            ctrl: _tpCtrl,
            focus: _tpFocus,
            onToggle: (v) {
              _unfocus();
              setState(() {
                _tpOn = v;
                if (!v) {
                  _tp = null;
                  _tpCtrl.clear();
                } else if (_tpCtrl.text.isEmpty) {
                  final q = tradingService.quoteFor(_symbol);
                  final mark = _pos.isBuy
                      ? (q?.bid ?? _pos.currentPrice)
                      : (q?.ask ?? _pos.currentPrice);
                  final seed = _pos.isBuy
                      ? mark + 50 * _priceStep
                      : mark - 50 * _priceStep;
                  _tp = _round(seed);
                  _tpCtrl.text = _tp!.toStringAsFixed(_digits);
                }
              });
            },
          ),
          if (_tpOn) _priceField(_tpCtrl, _tpFocus, (v) {
            final p = double.tryParse(v.trim());
            _tp = (p != null && p > 0) ? p : null;
          }),
          const Divider(height: 8, thickness: 0.7, color: _cardLine),
          _tpSlRow(
            label: 'Stop Loss',
            on: _slOn,
            ctrl: _slCtrl,
            focus: _slFocus,
            onToggle: (v) {
              _unfocus();
              setState(() {
                _slOn = v;
                if (!v) {
                  _sl = null;
                  _slCtrl.clear();
                } else if (_slCtrl.text.isEmpty) {
                  final q = tradingService.quoteFor(_symbol);
                  final mark = _pos.isBuy
                      ? (q?.bid ?? _pos.currentPrice)
                      : (q?.ask ?? _pos.currentPrice);
                  final seed = _pos.isBuy
                      ? mark - 50 * _priceStep
                      : mark + 50 * _priceStep;
                  _sl = _round(seed);
                  _slCtrl.text = _sl!.toStringAsFixed(_digits);
                }
              });
            },
          ),
          if (_slOn) _priceField(_slCtrl, _slFocus, (v) {
            final p = double.tryParse(v.trim());
            _sl = (p != null && p > 0) ? p : null;
          }),
        ],
      ),
    );
  }

  Widget _tpSlRow({
    required String label,
    required bool on,
    required TextEditingController ctrl,
    required FocusNode focus,
    required ValueChanged<bool> onToggle,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: OcColors.text,
            ),
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch.adaptive(
            value: on,
            activeThumbColor: Colors.white,
            activeTrackColor: OcColors.primary,
            onChanged: onToggle,
          ),
        ),
      ],
    );
  }

  Widget _priceField(
    TextEditingController ctrl,
    FocusNode focus,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: OcColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _cardLine),
        ),
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_priceFormat],
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
          ),
          onChanged: onChanged,
          onEditingComplete: () => setState(() {}),
        ),
      ),
    );
  }

  Widget _pnlCard(double pnl, bool profit) {
    final accent = profit ? OcColors.profit : OcColors.loss;
    final bg = profit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final border = profit ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_cardR),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                profit ? Icons.trending_up : Icons.trending_down,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Current P&L: \$${formatMoney(pnl)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _kv(
            'Full Position:',
            '\$${formatMoney(_pos.floatingPnL)}',
            valueColor: _pos.floatingPnL >= 0 ? OcColors.profit : OcColors.loss,
          ),
          SizedBox(height: 3),
          _kv(
            'Closing:',
            '${_volume.toStringAsFixed(2)} lots',
            valueColor: OcColors.text,
            valueBold: true,
          ),
        ],
      ),
    );
  }

  Widget _kv(
    String label,
    String value, {
    required Color valueColor,
    bool valueBold = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: OcColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12.5,
            fontWeight: valueBold ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _closeButton(double pnl, bool profit) {
    final bg = profit ? OcColors.profit : OcColors.loss;
    final label = profit
        ? 'Close with Profit +\$${formatMoney(pnl.abs())}'
        : 'Close with Loss \$${formatMoney(pnl)}';
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : _submitClose,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: bg.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          _busy ? 'Closing…' : label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _LiveBidAskCard extends StatefulWidget {
  const _LiveBidAskCard({required this.symbol});
  final String symbol;

  @override
  State<_LiveBidAskCard> createState() => _LiveBidAskCardState();
}

class _LiveBidAskCardState extends State<_LiveBidAskCard> {
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    tradingService.addListener(_onTick);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 200) return;
    _last = now;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final q = tradingService.quoteFor(widget.symbol);
    final bid = q?.bid ?? 0;
    final ask = q?.ask ?? 0;
    final digits = q?.digits ?? digitsFor(widget.symbol, bid);

    Widget side(String label, String value, Color valueColor) {
      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: OcColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: valueColor,
                height: 1.1,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _OceanaCloseModifyPageState._cardBg,
        borderRadius:
            BorderRadius.circular(_OceanaCloseModifyPageState._cardR),
        border: Border.all(color: _OceanaCloseModifyPageState._cardLine),
      ),
      child: Row(
        children: [
          side(
            'Bid',
            bid > 0 ? bid.toStringAsFixed(digits) : '—',
            OcColors.bid,
          ),
          Container(
            width: 1,
            height: 28,
            color: _OceanaCloseModifyPageState._cardLine,
          ),
          side(
            'Ask',
            ask > 0 ? ask.toStringAsFixed(digits) : '—',
            OcColors.text,
          ),
        ],
      ),
    );
  }
}
