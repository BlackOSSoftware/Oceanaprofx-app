import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/shell_controller.dart';
import '../../core/trade_sound.dart';
import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';
import 'chart_models.dart';
import 'oceana_chart_style_sheet.dart';
import 'oceana_indicator_sheet.dart';
import 'oceana_symbol_picker_page.dart';
import 'oceana_timeframe_sheet.dart';
import 'trading_view_chart.dart';
import '../trade/oceana_pending_order_page.dart';

/// Oceana Chart tab — TradingView Lightweight Charts + broker live prices.
class OceanaChartsScreen extends StatefulWidget {
  const OceanaChartsScreen({
    super.key,
    required this.symbol,
    this.active = true,
  });

  final String symbol;
  final bool active;

  @override
  State<OceanaChartsScreen> createState() => _OceanaChartsScreenState();
}

class _OceanaChartsScreenState extends State<OceanaChartsScreen> {
  ChartTimeframe _tf = ChartTimeframes.of('M1');
  String _chartStyle = '1'; // candles
  final Set<String> _activeIndicators = {};

  double _volume = 0.01;
  bool _busy = false;
  bool _switching = false;
  final _volumeCtrl = TextEditingController(text: '0.01');
  final _volumeFocus = FocusNode();

  /// Digits + optional 1 decimal point, max 2 decimals (e.g. 0.01 … 100).
  static final _qtyFormat = TextInputFormatter.withFunction((oldV, newV) {
    if (newV.text.isEmpty) return newV;
    return RegExp(r'^\d{1,3}(\.\d{0,2})?$').hasMatch(newV.text) ? newV : oldV;
  });

  static const _minLot = 0.01;
  static const _maxLot = 100.0;
  static const _lotStep = 0.01;

  /// Quick lot deltas under quantity (minus → plus).
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

  @override
  void initState() {
    super.initState();
    // Detach any stale tear-off left by hot reload (old _onLive).
    tradingService.removeListener(_onLive);
    tradingService.subscribe(widget.symbol);
  }

  /// Kept as a no-op so hot-reload tear-offs of the old method don't crash.
  void _onLive() {}

  @override
  void didUpdateWidget(covariant OceanaChartsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      tradingService.subscribe(widget.symbol);
    }
    // Returning to Chart tab — ensure live quote subscription is warm.
    if (!oldWidget.active && widget.active) {
      tradingService.subscribe(widget.symbol);
    }
  }

  @override
  void dispose() {
    tradingService.removeListener(_onLive);
    _volumeCtrl.dispose();
    _volumeFocus.dispose();
    super.dispose();
  }

  void _bumpVolume(double delta) {
    // Update controller only — avoid setState (keeps WebView from rebuilding).
    _volume = ((_volume + delta) * 100).round() / 100;
    if (_volume < _minLot) _volume = _minLot;
    if (_volume > _maxLot) _volume = _maxLot;
    _volumeCtrl.text = _volume.toStringAsFixed(2);
    _volumeCtrl.selection = TextSelection.collapsed(
      offset: _volumeCtrl.text.length,
    );
  }

  String _fmtLotDelta(double d) {
    final abs = d.abs();
    final body = abs == abs.roundToDouble()
        ? abs.toStringAsFixed(0)
        : abs.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
              RegExp(r'\.$'),
              '',
            );
    return d < 0 ? '-$body' : '+$body';
  }

  bool _canApplyLotDelta(double delta) {
    final typed = double.tryParse(_volumeCtrl.text.trim()) ?? _volume;
    final next = ((typed + delta) * 100).round() / 100;
    if (delta < 0) return typed > _minLot && next >= _minLot - 1e-9;
    return typed < _maxLot;
  }

  void _syncVolumeFromField({bool showError = false}) {
    final raw = _volumeCtrl.text.trim();
    final parsed = double.tryParse(raw);
    if (parsed == null || raw.isEmpty || raw == '.') {
      _volume = _minLot;
      _volumeCtrl.text = _minLot.toStringAsFixed(2);
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid quantity')),
        );
      }
      return;
    }
    var v = (parsed * 100).round() / 100;
    String? msg;
    if (v < _minLot) {
      v = _minLot;
      msg = 'Minimum lot is ${_minLot.toStringAsFixed(2)}';
    } else if (v > _maxLot) {
      v = _maxLot;
      msg = 'Maximum lot is ${_maxLot.toStringAsFixed(0)}';
    }
    _volume = v;
    _volumeCtrl.text = v.toStringAsFixed(2);
    if (showError && msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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

  Future<void> _pickTimeframe() async {
    final picked = await showOceanaTimeframeSheet(
      context,
      selected: _tf.code,
    );
    if (picked == null || !mounted) return;
    setState(() => _tf = ChartTimeframes.of(picked));
  }

  Future<void> _pickChartStyle() async {
    final picked = await showOceanaChartStyleSheet(
      context,
      selected: _chartStyle,
    );
    if (picked == null || !mounted) return;
    setState(() => _chartStyle = picked);
  }

  Future<void> _pickIndicators() async {
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
  }

  Future<void> _pickSymbol() async {
    if (tradingService.watchlist.isEmpty) return;
    final picked = await OceanaSymbolPickerPage.open(
      context,
      selected: widget.symbol,
    );
    if (!mounted) return;
    if (picked != null && picked != widget.symbol) {
      ShellScope.of(context).openChart(picked);
    }
  }

  Future<void> _trade(String side) async {
    if (_busy) return;
    _volumeFocus.unfocus();
    _syncVolumeFromField(showError: true);
    if (_volume < _minLot || _volume > _maxLot) return;

    final q = tradingService.quoteFor(widget.symbol);
    if (q == null || !q.hasPrice) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No live price — try again')),
      );
      return;
    }

    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    try {
      await tradingService.placeMarketOrder(
        symbol: widget.symbol,
        side: side,
        volume: _volume,
      );
      unawaited(TradeSound.ok());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$side ${widget.symbol} ${_volume.toStringAsFixed(2)} lot',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      unawaited(TradeSound.error());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showAccountSheet() async {
    if (_switching) return;
    if (tradingService.hasUserPortal) {
      try {
        await tradingService.refreshLinkedAccounts();
      } catch (_) {}
      if (!mounted) return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: OcColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: tradingService,
          builder: (ctx, _) {
            final session = tradingService.session;
            final sessionNum = session?.accountNumber.trim() ?? '';
            final sessionId = session?.accountId.trim() ?? '';
            final accounts = tradingService.linkedAccounts
                .where((a) => a.accountNumber.trim().isNotEmpty)
                .toList();
            final rows = accounts.isNotEmpty
                ? accounts
                : [
                    if (session != null && sessionNum.isNotEmpty)
                      LinkedTradingAccount(
                        id: session.accountId,
                        accountNumber: session.accountNumber,
                        accountType: tradingService.isActiveAccountDemo
                            ? 'demo'
                            : 'live',
                        balance: tradingService.account.balance,
                        equity: tradingService.account.equity,
                        isPrimary: true,
                      ),
                  ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Select Account',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(OcIcons.x),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    for (final a in rows)
                      _ChartAccountTile(
                        account: a,
                        active: (sessionId.isNotEmpty && a.id == sessionId) ||
                            (sessionNum.isNotEmpty &&
                                a.accountNumber.trim() == sessionNum),
                        onTap: () async {
                          final isActive =
                              (sessionId.isNotEmpty && a.id == sessionId) ||
                                  (sessionNum.isNotEmpty &&
                                      a.accountNumber.trim() == sessionNum);
                          if (isActive) {
                            Navigator.pop(ctx);
                            return;
                          }
                          Navigator.pop(ctx);
                          setState(() => _switching = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            if (a.id.isNotEmpty &&
                                tradingService.hasUserPortal) {
                              await tradingService.activateLinkedAccount(a.id);
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot switch — sign in again to use this account',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  e
                                      .toString()
                                      .replaceFirst('Exception: ', ''),
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _switching = false);
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard (symbol search / qty) must NOT resize the TradingView WebView.
    return MediaQuery.removeViewInsets(
      removeBottom: true,
      context: context,
      child: Scaffold(
        backgroundColor: OcColors.surface,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _LiveHeader(
                symbol: widget.symbol,
                active: widget.active,
                onApps: () => ShellScope.of(context).openTab(3),
                onAccount: _switching ? null : _showAccountSheet,
                onPickSymbol: _pickSymbol,
              ),
              _toolbar(),
              Expanded(
                child: RepaintBoundary(child: _chartBody()),
              ),
              _qtyRow(),
              _lotQuickRow(),
              _LiveBuySell(
                symbol: widget.symbol,
                active: widget.active,
                busy: _busy,
                onTrade: _trade,
              ),
              _pendingRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: OcColors.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _qtyStepBtn(
              icon: OcIcons.minus,
              onTap: () => _bumpVolume(-_lotStep),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Quantity (lots)',
                    style: TextStyle(
                      fontSize: 10,
                      color: OcColors.textMuted,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(
                    height: 22,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                      child: TextField(
                        controller: _volumeCtrl,
                        focusNode: _volumeFocus,
                        textAlign: TextAlign.center,
                        cursorColor: OcColors.primary,
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_qtyFormat],
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          height: 1.1,
                          color: OcColors.text,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v.trim());
                          if (parsed != null) _volume = parsed;
                        },
                        onEditingComplete: () {
                          _syncVolumeFromField(showError: true);
                          _volumeFocus.unfocus();
                        },
                        onTapOutside: (_) {
                          _syncVolumeFromField(showError: true);
                          _volumeFocus.unfocus();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _qtyStepBtn(
              icon: OcIcons.plus,
              onTap: () => _bumpVolume(_lotStep),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lotQuickRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: SizedBox(
        height: 30,
        child: AnimatedBuilder(
          animation: _volumeCtrl,
          builder: (context, _) {
            return ListView.separated(
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
                    onTap: enabled
                        ? () {
                            _volumeFocus.unfocus();
                            _bumpVolume(delta);
                          }
                        : null,
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
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPending() async {
    _volumeFocus.unfocus();
    _syncVolumeFromField();
    await OceanaPendingOrderPage.open(
      context,
      symbol: widget.symbol,
      volume: _volume,
    );
  }

  Widget _pendingRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _openPending,
                style: FilledButton.styleFrom(
                  backgroundColor: OcColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Pending order  •  SL  •  TP',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: OcColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(
                  OcIcons.bell,
                  size: 20,
                  color: OcColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// SS: 1m · candle · fx Indicators ····· gear · fullscreen
  Widget _toolbar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 4, 2),
      child: Row(
        children: [
          InkWell(
            onTap: _pickTimeframe,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                _tfLabel(_tf),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: OcColors.text,
                ),
              ),
            ),
          ),
          SizedBox(width: 2),
          InkWell(
            onTap: _pickChartStyle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Icon(
                OcIcons.candlestickChart,
                size: 18,
                color: OcColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: 6),
          InkWell(
            onTap: _pickIndicators,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Text(
                    'fx',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: OcColors.primary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Indicators',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: OcColors.text,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Spacer(),
          IconButton(
            onPressed: () {},
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              OcIcons.settings,
              size: 18,
              color: OcColors.textSecondary,
            ),
          ),
          IconButton(
            onPressed: () {},
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              Icons.fullscreen_rounded,
              size: 22,
              color: OcColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartBody() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: OcColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OcColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: TradingViewChart(
        key: ValueKey(
          '${widget.symbol}|${_tf.code}|$_chartStyle|${OcColors.isDark ? 'd' : 'l'}',
        ),
        symbol: widget.symbol,
        timeframe: _tf.code,
        interval: TradingViewChart.intervalFromCode(_tf.code),
        style: _chartStyle,
        studies: _activeIndicators.toList()..sort(),
        active: widget.active,
      ),
    );
  }

  Widget _qtyStepBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: OcColors.primary.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 16, color: OcColors.primary),
          ),
        ),
      ),
    );
  }

}

double _pow10(int n) {
  var x = 1.0;
  for (var i = 0; i < n; i++) {
    x *= 10;
  }
  return x;
}

/// Live PnL/account header — own tick listener (does not rebuild WebView).
class _LiveHeader extends StatefulWidget {
  const _LiveHeader({
    required this.symbol,
    required this.active,
    required this.onApps,
    required this.onPickSymbol,
    this.onAccount,
  });

  final String symbol;
  final bool active;
  final VoidCallback onApps;
  final VoidCallback? onAccount;
  final VoidCallback onPickSymbol;

  @override
  State<_LiveHeader> createState() => _LiveHeaderState();
}

class _LiveHeaderState extends State<_LiveHeader> {
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    tradingService.addListener(_onLive);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onLive);
    super.dispose();
  }

  void _onLive() {
    if (!mounted || !widget.active) return;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 200) return;
    _last = now;
    setState(() {});
  }

  String _accountNumber() {
    final n = tradingService.session?.accountNumber.trim() ?? '';
    return n.isNotEmpty ? n : '—';
  }

  @override
  Widget build(BuildContext context) {
    final pnl = tradingService.positions.values.fold<double>(
      0,
      (s, p) => s + p.floatingPnL,
    );
    final pnlColor = pnl >= 0 ? OcColors.profit : OcColors.loss;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onApps,
            icon: _FourDots(size: 18),
          ),
          Expanded(
            child: InkWell(
              onTap: widget.onAccount,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${formatMoney(pnl)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: pnlColor,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: OcColors.primarySoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tradingService.isActiveAccountDemo ? 'DEMO' : 'LIVE',
                          style: TextStyle(
                            color: OcColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _accountNumber(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: OcColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(
                        OcIcons.chevronDown,
                        size: 16,
                        color: OcColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: OcColors.primarySoft,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: widget.onPickSymbol,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.symbol,
                      style: TextStyle(
                        color: OcColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      OcIcons.chevronDown,
                      size: 16,
                      color: OcColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartAccountTile extends StatelessWidget {
  const _ChartAccountTile({
    required this.account,
    required this.active,
    required this.onTap,
  });

  final LinkedTradingAccount account;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bal = account.equity > 0 ? account.equity : account.balance;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: OcColors.bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: account.isDemo
                        ? OcColors.primarySoft
                        : OcColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    OcIcons.wallet,
                    color: account.isDemo ? OcColors.primary : Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            account.planName.trim().isNotEmpty
                                ? account.planName.trim()
                                : (account.isDemo ? 'Demo' : 'Live'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          if (active) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: OcColors.depositBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: OcColors.depositFg,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${account.isDemo ? 'Demo' : 'Live'} · ${account.accountNumber}',
                        style: TextStyle(
                          color: OcColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${formatMoney(bal)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: OcColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  active ? OcIcons.radioChecked : OcIcons.radioUnchecked,
                  color: active ? OcColors.primary : OcColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live bid/ask row — own tick listener (does not rebuild WebView).
class _LiveBuySell extends StatefulWidget {
  const _LiveBuySell({
    required this.symbol,
    required this.active,
    required this.busy,
    required this.onTrade,
  });

  final String symbol;
  final bool active;
  final bool busy;
  final Future<void> Function(String side) onTrade;

  @override
  State<_LiveBuySell> createState() => _LiveBuySellState();
}

class _LiveBuySellState extends State<_LiveBuySell> {
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    tradingService.addListener(_onLive);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onLive);
    super.dispose();
  }

  void _onLive() {
    if (!mounted || !widget.active) return;
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 120) return;
    _last = now;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final q = tradingService.quoteFor(widget.symbol);
    final bid = q?.bid ?? 0;
    final ask = q?.ask ?? 0;
    final digits = q?.digits ?? 5;
    final spreadPts =
        (bid > 0 && ask > 0) ? ((ask - bid) * _pow10(digits)) : 0.0;
    final spreadLabel = spreadPts > 0 ? spreadPts.toStringAsFixed(1) : '—';
    final canTap = !widget.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: _sideBtn(
                    label: 'SELL',
                    price: bid,
                    digits: digits,
                    color: OcColors.bid,
                    // Bid → SELL market order
                    onTap: canTap ? () => widget.onTrade('SELL') : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _sideBtn(
                    label: 'BUY',
                    price: ask,
                    digits: digits,
                    color: OcColors.ask,
                    // Ask → BUY market order
                    onTap: canTap ? () => widget.onTrade('BUY') : null,
                  ),
                ),
              ],
            ),
            IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: OcColors.surface,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: OcColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: OcColors.isDark ? 0.35 : 0.08),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  spreadLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: OcColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideBtn({
    required String label,
    required double price,
    required int digits,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 52,
      child: Material(
        color: onTap == null ? color.withValues(alpha: 0.45) : color,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  price > 0 ? price.toStringAsFixed(digits) : '—',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.1,
                    color: Colors.white,
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

class _FourDots extends StatelessWidget {
  const _FourDots({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    const gap = 3.0;
    final d = (size - gap) / 2;
    Widget dot() => Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            color: OcColors.text,
            shape: BoxShape.circle,
          ),
        );
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [dot(), dot()],
          ),
        ],
      ),
    );
  }
}
