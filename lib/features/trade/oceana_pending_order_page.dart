import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/trade_sound.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import '../../ui/widgets/oc_trade_result_dialog.dart';
import '../charts/oceana_chart_style_sheet.dart';
import '../charts/oceana_indicator_sheet.dart';
import '../charts/oceana_timeframe_sheet.dart';
import '../charts/chart_indicators.dart';
import '../charts/chart_models.dart';
import '../charts/trading_view_chart.dart';
import '../quotes/symbol_flags.dart';

/// Pending order screen — matches Tenax/SS layout (brand `#1414C7`).
/// Pass [existing] to edit an open pending (modifyPending) — never place a new one.
class OceanaPendingOrderPage extends StatefulWidget {
  const OceanaPendingOrderPage({
    super.key,
    required this.symbol,
    this.initialVolume = 0.01,
    this.existing,
  });

  final String symbol;
  final double initialVolume;
  final PendingOrder? existing;

  static Future<void> open(
    BuildContext context, {
    required String symbol,
    double volume = 0.01,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OceanaPendingOrderPage(
          symbol: symbol,
          initialVolume: volume,
        ),
      ),
    );
  }

  static Future<void> openModify(BuildContext context, PendingOrder order) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OceanaPendingOrderPage(
          symbol: order.symbol,
          initialVolume: order.volume,
          existing: order,
        ),
      ),
    );
  }

  @override
  State<OceanaPendingOrderPage> createState() => _OceanaPendingOrderPageState();
}

class _OceanaPendingOrderPageState extends State<OceanaPendingOrderPage> {
  static const _types = <(String, String)>[
    ('BUY_LIMIT', 'Buy Limit'),
    ('SELL_LIMIT', 'Sell Limit'),
    ('BUY_STOP', 'Buy Stop'),
    ('SELL_STOP', 'Sell Stop'),
    ('BUY_STOP_LIMIT', 'Buy Stop Limit'),
    ('SELL_STOP_LIMIT', 'Sell Stop Limit'),
  ];

  static const _minLot = 0.01;
  static const _maxLot = 100.0;
  static const _lotStep = 0.01;

  static const _lotQuickDeltas = <double>[
    -1,
    -0.5,
    -0.1,
    -0.05,
    -0.01,
    0.01,
    0.05,
    0.1,
    0.5,
    1,
  ];

  late String _symbol;
  String _type = 'BUY_LIMIT';
  double _volume = 0.01;
  double? _price;
  double? _limitPrice;
  bool _tpOn = false;
  bool _slOn = false;
  double? _tp;
  double? _sl;
  bool _showChart = false;
  bool _busy = false;

  ChartTimeframe _tf = ChartTimeframes.of('M1');
  String _chartStyle = '1';
  final List<ChartIndicatorConfig> _indicators = [];

  final _volumeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _slCtrl = TextEditingController();

  final _volumeFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _limitFocus = FocusNode();
  final _tpFocus = FocusNode();
  final _slFocus = FocusNode();

  /// Allow 0.01 … 100 — no leading zeros like 0005 / 05.
  static final _qtyFormat = TextInputFormatter.withFunction((oldV, newV) {
    final t = newV.text;
    if (t.isEmpty) return newV;
    if (!RegExp(r'^(0|[1-9]\d{0,2})(\.\d{0,2})?$').hasMatch(t)) {
      return oldV;
    }
    return newV;
  });

  static final _priceFormat = TextInputFormatter.withFunction((oldV, newV) {
    if (newV.text.isEmpty) return newV;
    return RegExp(r'^\d{1,9}(\.\d{0,6})?$').hasMatch(newV.text) ? newV : oldV;
  });

  bool get _isEdit => widget.existing != null;
  bool get _isBuy => _type.startsWith('BUY');
  bool get _isStopLimit => _type.contains('STOP_LIMIT');
  String get _typeLabel =>
      _types.firstWhere((t) => t.$1 == _type, orElse: () => _types.first).$2;

  @override
  void initState() {
    super.initState();
    _symbol = widget.symbol;
    final existing = widget.existing;
    if (existing != null) {
      final t = existing.orderType.trim().toUpperCase();
      if (_types.any((e) => e.$1 == t)) _type = t;
      _volume = existing.volume.clamp(_minLot, _maxLot);
      _volumeCtrl.text = _volume.toStringAsFixed(2);
      if (existing.price > 0) {
        _price = existing.price;
        _priceCtrl.text = existing.price.toStringAsFixed(
          digitsFor(_symbol, existing.price),
        );
      }
      final tp = existing.takeProfit;
      if (tp != null && tp > 0) {
        _tpOn = true;
        _tp = tp;
        _tpCtrl.text = tp.toStringAsFixed(digitsFor(_symbol, tp));
      }
      final sl = existing.stopLoss;
      if (sl != null && sl > 0) {
        _slOn = true;
        _sl = sl;
        _slCtrl.text = sl.toStringAsFixed(digitsFor(_symbol, sl));
      }
    } else {
      _volume = widget.initialVolume.clamp(_minLot, _maxLot);
      _volumeCtrl.text = _volume.toStringAsFixed(2);
    }
    tradingService.subscribe(_symbol);
    // Do NOT addListener(setState) here — every tick rebuilt the form and
    // killed the keyboard + froze the UI. Bid/Ask lives in its own widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isEdit) _seedPrice();
    });
  }

  @override
  void dispose() {
    _volumeFocus.dispose();
    _priceFocus.dispose();
    _limitFocus.dispose();
    _tpFocus.dispose();
    _slFocus.dispose();
    _volumeCtrl.dispose();
    _priceCtrl.dispose();
    _limitCtrl.dispose();
    _tpCtrl.dispose();
    _slCtrl.dispose();
    super.dispose();
  }

  void _unfocusAll() {
    _volumeFocus.unfocus();
    _priceFocus.unfocus();
    _limitFocus.unfocus();
    _tpFocus.unfocus();
    _slFocus.unfocus();
  }

  void _syncVolumeFromField() {
    final raw = _volumeCtrl.text.trim();
    final parsed = double.tryParse(raw);
    if (parsed == null || raw.isEmpty || raw == '.') {
      _volume = _minLot;
    } else {
      var v = (parsed * 100).round() / 100;
      if (v < _minLot) v = _minLot;
      if (v > _maxLot) v = _maxLot;
      _volume = v;
    }
    _volumeCtrl.text = _volume.toStringAsFixed(2);
    _volumeCtrl.selection = TextSelection.collapsed(
      offset: _volumeCtrl.text.length,
    );
  }

  LiveQuote? get _q => tradingService.quoteFor(_symbol);

  int get _digits {
    final q = _q;
    return q?.digits ?? digitsFor(_symbol, q?.bid ?? 0);
  }

  double get _point => math.pow(10, -_digits).toDouble();
  double get _priceStep => _point * 10;

  void _seedPrice() {
    final q = _q;
    if (q == null || !q.hasPrice) return;
    if (_price != null && _price! > 0) return;
    final seed = _isBuy ? q.ask : q.bid;
    _setPrice(seed);
  }

  void _setPrice(double v) {
    final r = _round(v);
    _price = r;
    _priceCtrl.text = r.toStringAsFixed(_digits);
    setState(() {});
  }

  double _round(double v) {
    final f = math.pow(10, _digits).toDouble();
    return (v * f).round() / f;
  }

  /// Trigger price vs live bid/ask (MT5 pending rules).
  String? _priceHint() {
    final p = _price;
    final q = _q;
    if (p == null || p <= 0 || q == null || !q.hasPrice) return null;
    final bid = q.bid;
    final ask = q.ask;
    final a = ask.toStringAsFixed(_digits);
    final b = bid.toStringAsFixed(_digits);
    return switch (_type) {
      'BUY_LIMIT' when !(p < ask) => 'Buy Limit price should be below $a',
      'SELL_LIMIT' when !(p > bid) => 'Sell Limit price should be above $b',
      'BUY_STOP' when !(p > ask) => 'Buy Stop price should be above $a',
      'SELL_STOP' when !(p < bid) => 'Sell Stop price should be below $b',
      'BUY_STOP_LIMIT' when !(p > ask) =>
        'Buy Stop Limit price should be above $a',
      'SELL_STOP_LIMIT' when !(p < bid) =>
        'Sell Stop Limit price should be below $b',
      _ => null,
    };
  }

  /// Stop Limit: limit price must sit correctly vs stop (trigger) price.
  String? _limitHint() {
    if (!_isStopLimit) return null;
    final stop = _price;
    final lim = _limitPrice;
    if (stop == null || stop <= 0) return null;
    if (lim == null || lim <= 0) return 'Enter stop limit price';
    final s = stop.toStringAsFixed(_digits);
    if (_type == 'BUY_STOP_LIMIT' && !(lim <= stop)) {
      return 'Buy Stop Limit price should be at or below $s';
    }
    if (_type == 'SELL_STOP_LIMIT' && !(lim >= stop)) {
      return 'Sell Stop Limit price should be at or above $s';
    }
    return null;
  }

  /// TP must be on profit side of entry.
  String? _tpHint() {
    if (!_tpOn) return null;
    final entry = _price;
    final tp = _tp;
    if (entry == null || entry <= 0) return null;
    if (tp == null || tp <= 0) return 'Enter take profit';
    if (_isBuy && !(tp > entry)) {
      return 'Take Profit should be above ${entry.toStringAsFixed(_digits)}';
    }
    if (!_isBuy && !(tp < entry)) {
      return 'Take Profit should be below ${entry.toStringAsFixed(_digits)}';
    }
    return null;
  }

  /// SL must be on loss side of entry.
  String? _slHint() {
    if (!_slOn) return null;
    final entry = _price;
    final sl = _sl;
    if (entry == null || entry <= 0) return null;
    if (sl == null || sl <= 0) return 'Enter stop loss';
    if (_isBuy && !(sl < entry)) {
      return 'Stop Loss should be below ${entry.toStringAsFixed(_digits)}';
    }
    if (!_isBuy && !(sl > entry)) {
      return 'Stop Loss should be above ${entry.toStringAsFixed(_digits)}';
    }
    return null;
  }

  bool get _placeValid {
    final p = _price;
    if (p == null || p <= 0) return false;
    if (_volume < _minLot || _volume > _maxLot) return false;
    if (_isStopLimit && (_limitPrice == null || _limitPrice! <= 0)) {
      return false;
    }
    if (_tpOn && (_tp == null || _tp! <= 0)) return false;
    if (_slOn && (_sl == null || _sl! <= 0)) return false;
    return _priceHint() == null &&
        _limitHint() == null &&
        _tpHint() == null &&
        _slHint() == null;
  }

  /// Rough $ estimate: lots × 100000 × |Î”price| (UI only).
  double? _potentialAt(double? level, {required bool isTp}) {
    final entry = _price;
    if (entry == null || level == null || level <= 0) return null;
    final diff = isTp
        ? (_isBuy ? level - entry : entry - level)
        : (_isBuy ? entry - level : level - entry);
    if (diff <= 0) return null;
    return _volume * 100000 * diff;
  }

  Future<void> _pickType() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: OcColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, 12, 0, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Order Type',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OcColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                for (final t in _types)
                  InkWell(
                    onTap: () => Navigator.pop(ctx, t.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          t.$2,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: t.$1 == _type
                                ? OcColors.primary
                                : OcColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _type = picked;
      _price = null;
      _limitPrice = null;
      _priceCtrl.clear();
      _limitCtrl.clear();
    });
    _seedPrice();
  }

  void _bumpVolume(double d) {
    if (_isEdit) return; // API modifyPending does not change volume.
    _unfocusAll();
    _syncVolumeFromField();
    _volume = ((_volume + d) * 100).round() / 100;
    if (_volume < _minLot) _volume = _minLot;
    if (_volume > _maxLot) _volume = _maxLot;
    _volumeCtrl.text = _volume.toStringAsFixed(2);
    setState(() {});
  }

  String _fmtLotDelta(double d) {
    final abs = d.abs();
    final body = abs == abs.roundToDouble()
        ? abs.toStringAsFixed(0)
        : abs
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
    return d < 0 ? '-$body' : '+$body';
  }

  bool _canApplyLotDelta(double delta) {
    if (_isEdit) return false;
    final typed = double.tryParse(_volumeCtrl.text.trim()) ?? _volume;
    if (delta < 0) return typed > _minLot;
    return typed < _maxLot;
  }

  Widget _lotQuickRow() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _lotQuickDeltas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final delta = _lotQuickDeltas[i];
          final neg = delta < 0;
          final enabled = _canApplyLotDelta(delta);
          // Soft pastel — not deposit/withdraw button colors.
          final bg = neg
              ? (OcColors.isDark
                  ? const Color(0xFF3A181C)
                  : const Color(0xFFFFEBEE))
              : (OcColors.isDark
                  ? const Color(0xFF16301C)
                  : const Color(0xFFE8F5E9));
          final fg = neg
              ? (OcColors.isDark
                  ? const Color(0xFFFF8A8A)
                  : const Color(0xFFC62828))
              : (OcColors.isDark
                  ? const Color(0xFF8FD99A)
                  : const Color(0xFF2E7D32));
          return Material(
            color: enabled ? bg : OcColors.bg,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: enabled ? () => _bumpVolume(delta) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: enabled
                        ? fg.withValues(alpha: 0.28)
                        : OcColors.border,
                  ),
                ),
                child: Text(
                  _fmtLotDelta(delta),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: enabled ? fg : OcColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _bumpPrice(double dir) {
    final base = _price ?? (_isBuy ? (_q?.ask ?? 0) : (_q?.bid ?? 0));
    if (base <= 0) return;
    _setPrice(base + dir * _priceStep);
  }

  void _bumpLevel({
    required bool tp,
    required double dir,
  }) {
    final digits = _digits;
    final step = _priceStep;
    final ctrl = tp ? _tpCtrl : _slCtrl;
    final cur = double.tryParse(ctrl.text) ??
        (_price ?? 0) + (tp ? (_isBuy ? 50 : -50) : (_isBuy ? -50 : 50)) * _point;
    final next = _round(cur + dir * step);
    ctrl.text = next.toStringAsFixed(digits);
    setState(() {
      if (tp) {
        _tp = next;
      } else {
        _sl = next;
      }
    });
  }

  Future<void> _submit() async {
    if (_busy || !_placeValid) return;
    _syncVolumeFromField();
    final pp = double.tryParse(_priceCtrl.text.trim());
    _price = (pp != null && pp > 0) ? _round(pp) : null;
    if (_isStopLimit) {
      final lp = double.tryParse(_limitCtrl.text.trim());
      _limitPrice = (lp != null && lp > 0) ? _round(lp) : null;
    }
    if (_tpOn) {
      final t = double.tryParse(_tpCtrl.text.trim());
      _tp = (t != null && t > 0) ? _round(t) : null;
    } else {
      _tp = null;
    }
    if (_slOn) {
      final s = double.tryParse(_slCtrl.text.trim());
      _sl = (s != null && s > 0) ? _round(s) : null;
    } else {
      _sl = null;
    }
    if (_price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter order price')),
      );
      return;
    }
    final bad = _priceHint() ?? _limitHint() ?? _tpHint() ?? _slHint();
    if (bad != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bad)));
      return;
    }

    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    try {
      final existing = widget.existing;
      if (existing != null) {
        // Edit only — never place a second pending.
        await tradingService.modifyPending(
          orderId: existing.orderId,
          price: _price!,
          stopLoss: _slOn ? _sl : null,
          takeProfit: _tpOn ? _tp : null,
        );
        unawaited(TradeSound.ok());
        if (!mounted) return;
        await showOcTradeResult(
          context,
          title: 'Order updated',
          message: 'Pending order modified',
        );
      } else {
        await tradingService.placePendingOrder(
          symbol: _symbol,
          side: _isBuy ? 'BUY' : 'SELL',
          orderType: _type,
          price: _price!,
          limitPrice: _isStopLimit ? _limitPrice : null,
          volume: _volume,
          stopLoss: _slOn ? _sl : null,
          takeProfit: _tpOn ? _tp : null,
        );
        unawaited(TradeSound.ok());
        if (!mounted) return;
        await showOcTradeResult(
          context,
          title: 'Order placed',
          message: '$_typeLabel placed',
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      unawaited(TradeSound.error());
      if (!mounted) return;
      await showOcTradeResult(
        context,
        title: 'Order failed',
        message: '$e'.replaceFirst('Exception: ', ''),
        success: false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _cardR = 12.0;
  static const _fieldH = 48.0;
  static const _gap = 12.0;
  /// Page / cards follow OcColors so dark mode stays readable.
  static Color get _pageBg => OcColors.bg;
  static Color get _cardBg => OcColors.surface;
  static Color get _cardLine => OcColors.border;

  @override
  Widget build(BuildContext context) {
    final digits = _digits;
    final hint = _priceHint();
    final limitHint = _limitHint();
    final tpHint = _tpHint();
    final slHint = _slHint();
    final tpPot = _tpOn ? _potentialAt(_tp, isTp: true) : null;
    final slPot = _slOn ? _potentialAt(_sl, isTp: false) : null;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: _pageBg,
      // Avoid resizing the whole tree (esp. chart) on every keyboard frame.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 16 + bottomInset),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                children: [
                  _LiveBidAskCard(symbol: _symbol),
                  const SizedBox(height: _gap),
                  _chartToggle(),
                  if (_showChart) ...[
                    const SizedBox(height: 8),
                    _chartBlock(),
                  ],
                  const SizedBox(height: _gap),
                  _typeField(),
                  const SizedBox(height: 14),
                  _sectionLabel('Quantity (lots)'),
                  const SizedBox(height: 6),
                  _stepperField(
                    controller: _volumeCtrl,
                    focusNode: _volumeFocus,
                    onMinus: () => _bumpVolume(-_lotStep),
                    onPlus: () => _bumpVolume(_lotStep),
                    onChanged: (v) {
                      // No setState while typing — keeps keyboard open & smooth.
                      final p = double.tryParse(v.trim());
                      if (p != null) _volume = p;
                    },
                    onEditDone: () {
                      _syncVolumeFromField();
                      setState(() {});
                    },
                    formatters: [_qtyFormat],
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  _lotQuickRow(),
                  const SizedBox(height: 14),
                  _sectionLabel('When Price Is'),
                  const SizedBox(height: 6),
                  _stepperField(
                    controller: _priceCtrl,
                    focusNode: _priceFocus,
                    floatingLabel: 'Price',
                    onMinus: () => _bumpPrice(-1),
                    onPlus: () => _bumpPrice(1),
                    onChanged: (v) {
                      final p = double.tryParse(v.trim());
                      _price = (p != null && p > 0) ? p : null;
                    },
                    onEditDone: () => setState(() {}),
                    formatters: [_priceFormat],
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  if (hint != null) ...[
                    const SizedBox(height: 5),
                    _errorText(hint),
                  ],
                  if (_isStopLimit) ...[
                    const SizedBox(height: 14),
                    _sectionLabel('Stop Limit price'),
                    const SizedBox(height: 6),
                    _stepperField(
                      controller: _limitCtrl,
                      focusNode: _limitFocus,
                      floatingLabel: 'Limit',
                      onMinus: () {
                        final cur =
                            double.tryParse(_limitCtrl.text) ?? (_price ?? 0);
                        final n = _round(cur - _priceStep);
                        _limitCtrl.text = n.toStringAsFixed(digits);
                        setState(() => _limitPrice = n);
                      },
                      onPlus: () {
                        final cur =
                            double.tryParse(_limitCtrl.text) ?? (_price ?? 0);
                        final n = _round(cur + _priceStep);
                        _limitCtrl.text = n.toStringAsFixed(digits);
                        setState(() => _limitPrice = n);
                      },
                      onChanged: (v) {
                        final p = double.tryParse(v.trim());
                        _limitPrice = (p != null && p > 0) ? p : null;
                      },
                      onEditDone: () => setState(() {}),
                      formatters: [_priceFormat],
                      keyboard:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    if (limitHint != null) ...[
                      const SizedBox(height: 5),
                      _errorText(limitHint),
                    ],
                  ],
                  const SizedBox(height: 14),
                  _tpSlCard(
                    tpPot,
                    slPot,
                    digits,
                    tpHint: tpHint,
                    slHint: slHint,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: (_busy || !_placeValid) ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: OcColors.primary,
                        disabledBackgroundColor:
                            OcColors.primary.withValues(alpha: 0.4),
                        foregroundColor: OcColors.onPrimary,
                        disabledForegroundColor:
                            OcColors.onPrimary.withValues(alpha: 0.85),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _busy
                            ? (_isEdit ? 'Saving…' : 'Placing…')
                            : (_isEdit
                                ? 'Modify Order'
                                : 'Place Pending Order'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
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
              borderRadius: BorderRadius.circular(18),
            ),
            child: SymbolFlagPair(symbol: _symbol, size: 28),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Modify Order' : 'Pending Order',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: OcColors.text,
                    height: 1.15,
                  ),
                ),
                Text(
                  '$_typeLabel $_symbol',
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
                _unfocusAll();
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
                    _tfLabel(_tf),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  final p = await showOceanaChartStyleSheet(
                    context,
                    selected: _chartStyle,
                  );
                  if (p != null) setState(() => _chartStyle = p);
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
                    active: _indicators,
                    onChanged: (list) {
                      setState(() {
                        _indicators
                          ..clear()
                          ..addAll(list);
                      });
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      Text(
                        'fx',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: OcColors.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Indicators',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Icon(OcIcons.settings, size: 18, color: OcColors.textSecondary),
              const SizedBox(width: 8),
              Icon(Icons.fullscreen_rounded, size: 20, color: OcColors.textSecondary),
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
              '$_symbol|${_tf.code}|$_chartStyle|${_indicators.map((e) => e.instanceId).join(',')}',
            ),
            symbol: _symbol,
            timeframe: _tf.code,
            interval: TradingViewChart.intervalFromCode(_tf.code),
            style: _chartStyle,
            indicators: List<ChartIndicatorConfig>.from(_indicators),
          ),
        ),
      ],
    );
  }

  String _tfLabel(ChartTimeframe tf) {
    final c = tf.code;
    if (c.startsWith('M')) return '${c.substring(1)}m';
    if (c.startsWith('H')) return '${c.substring(1)}h';
    if (c == 'D1') return '1D';
    if (c == 'W1') return '1W';
    if (c == 'MN') return '1M';
    return c;
  }

  Widget _typeField() {
    return InkWell(
      onTap: _isEdit ? null : _pickType,
      borderRadius: BorderRadius.circular(_cardR),
      child: Container(
        height: _fieldH,
        padding: EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _pageBg,
          borderRadius: BorderRadius.circular(_cardR),
          border: Border.all(color: _cardLine),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _typeLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: OcColors.text,
                ),
              ),
            ),
            if (!_isEdit)
              Icon(OcIcons.chevronDown, size: 18, color: OcColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: OcColors.text,
      ),
    );
  }

  Widget _errorText(String text) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: OcColors.loss,
          fontWeight: FontWeight.w500,
          fontSize: 11.5,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _stepperField({
    required TextEditingController controller,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required ValueChanged<String> onChanged,
    FocusNode? focusNode,
    VoidCallback? onEditDone,
    List<TextInputFormatter>? formatters,
    TextInputType? keyboard,
    String? floatingLabel,
  }) {
    // Kill theme OutlineInputBorder/fill — otherwise nested "double box".
    final field = Container(
      height: _fieldH,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_cardR),
        border: Border.all(color: _cardLine, width: 1),
      ),
      child: Row(
        children: [
          _circleBtn(icon: OcIcons.minus, onTap: onMinus),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: const InputDecorationTheme(
                  filled: false,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                onEditingComplete: () {
                  onEditDone?.call();
                  focusNode?.unfocus();
                },
                textAlign: TextAlign.center,
                cursorColor: OcColors.primary,
                keyboardType: keyboard,
                inputFormatters: formatters,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: OcColors.text,
                  height: 1.15,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          _circleBtn(icon: OcIcons.plus, onTap: onPlus),
        ],
      ),
    );

    if (floatingLabel == null) return field;

    // SS: tiny "Price" caption centered on the top edge of the box.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(padding: const EdgeInsets.only(top: 7), child: field),
        Positioned(
          top: 0,
          child: ColoredBox(
            color: _pageBg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                floatingLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: OcColors.textMuted,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleBtn({required IconData icon, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: OcColors.primary, width: 1.35),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: OcColors.primary),
        ),
      ),
    );
  }

  Widget _tpSlCard(
    double? tpPot,
    double? slPot,
    int digits, {
    String? tpHint,
    String? slHint,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 6, 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(_cardR),
        border: Border.all(color: _cardLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toggleRow(
            title: 'Take Profit',
            value: _tpOn,
            onChanged: (v) {
              setState(() {
                _tpOn = v;
                if (v && _tpCtrl.text.isEmpty) {
                  final entry = _price ?? 0;
                  final seed = entry + (_isBuy ? 100 : -100) * _point;
                  _tp = _round(seed);
                  _tpCtrl.text = _tp!.toStringAsFixed(digits);
                }
              });
            },
          ),
          if (_tpOn) ...[
            _stepperField(
              controller: _tpCtrl,
              focusNode: _tpFocus,
              onMinus: () => _bumpLevel(tp: true, dir: -1),
              onPlus: () => _bumpLevel(tp: true, dir: 1),
              onChanged: (v) {
                final p = double.tryParse(v.trim());
                _tp = (p != null && p > 0) ? p : null;
              },
              onEditDone: () => setState(() {}),
              formatters: [_priceFormat],
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (tpHint != null) ...[
              const SizedBox(height: 4),
              _errorText(tpHint),
            ] else if (tpPot != null)
              _potRow('Potential Profit at TP', tpPot, OcColors.profit),
          ],
          Divider(height: 10, thickness: 0.7, color: _cardLine),
          _toggleRow(
            title: 'Stop Loss',
            value: _slOn,
            onChanged: (v) {
              setState(() {
                _slOn = v;
                if (v && _slCtrl.text.isEmpty) {
                  final entry = _price ?? 0;
                  final seed = entry + (_isBuy ? -100 : 100) * _point;
                  _sl = _round(seed);
                  _slCtrl.text = _sl!.toStringAsFixed(digits);
                }
              });
            },
          ),
          if (_slOn) ...[
            _stepperField(
              controller: _slCtrl,
              focusNode: _slFocus,
              onMinus: () => _bumpLevel(tp: false, dir: -1),
              onPlus: () => _bumpLevel(tp: false, dir: 1),
              onChanged: (v) {
                final p = double.tryParse(v.trim());
                _sl = (p != null && p > 0) ? p : null;
              },
              onEditDone: () => setState(() {}),
              formatters: [_priceFormat],
              keyboard: TextInputType.numberWithOptions(decimal: true),
            ),
            if (slHint != null) ...[
              SizedBox(height: 4),
              _errorText(slHint),
            ] else if (slPot != null)
              _potRow('Potential Loss at SL', slPot, OcColors.loss),
          ],
        ],
      ),
    );
  }

  Widget _potRow(String label, double amount, Color color) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2, 6, 6, 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: OcColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            '\$${formatMoney(amount)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
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
}

/// Live bid/ask only — own tick listener so typing fields never rebuild.
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
        color: _OceanaPendingOrderPageState._cardBg,
        borderRadius: BorderRadius.circular(_OceanaPendingOrderPageState._cardR),
        border: Border.all(color: _OceanaPendingOrderPageState._cardLine),
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
            color: _OceanaPendingOrderPageState._cardLine,
          ),
          side(
            'Ask',
            ask > 0 ? ask.toStringAsFixed(digits) : '—',
            OcColors.ask,
          ),
        ],
      ),
    );
  }
}
