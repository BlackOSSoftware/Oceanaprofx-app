import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mt_colors.dart';
import '../../core/trading_service.dart';

const _green = Color(0xFF43A047);

/// MT5 Market Statistics: Bid / Ask highs-lows, open/close, % change.
/// Data: Alltick daily kline (backend) + live ticks.
class MarketStatisticsPage extends StatefulWidget {
  const MarketStatisticsPage({
    super.key,
    required this.symbol,
    this.description = '',
  });

  final String symbol;
  final String description;

  @override
  State<MarketStatisticsPage> createState() => _MarketStatisticsPageState();
}

class _MarketStatisticsPageState extends State<MarketStatisticsPage> {
  Map<String, dynamic>? _api;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    tradingService.addListener(_onLive);
    _load();
  }

  @override
  void dispose() {
    tradingService.removeListener(_onLive);
    super.dispose();
  }

  void _onLive() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await tradingService.marketStatistics(widget.symbol);
      if (!mounted) return;
      _seedLiveExtremes(data);
      setState(() {
        _api = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  LiveQuote? get _live =>
      tradingService.quotes[widget.symbol.toUpperCase()] ??
      tradingService.quotes[widget.symbol];

  void _seedLiveExtremes(Map<String, dynamic> data) {
    final q = _live;
    if (q == null) return;
    double? n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
    final bh = n(data['bidHigh']);
    final bl = n(data['bidLow']);
    final ah = n(data['askHigh']);
    final al = n(data['askLow']);
    final open = n(data['open']);
    final close = n(data['close']);
    if (bh != null && bh > 0 && (q.bidHigh <= 0 || bh > q.bidHigh)) {
      q.bidHigh = bh;
    }
    if (bl != null && bl > 0 && (q.bidLow <= 0 || bl < q.bidLow)) {
      q.bidLow = bl;
    }
    if (ah != null && ah > 0 && (q.askHigh <= 0 || ah > q.askHigh)) {
      q.askHigh = ah;
    }
    if (al != null && al > 0 && (q.askLow <= 0 || al < q.askLow)) {
      q.askLow = al;
    }
    if (open != null && open > 0 && q.dayOpen <= 0) q.dayOpen = open;
    if (close != null && close > 0 && q.dayClose <= 0) q.dayClose = close;
    if (bh != null && bh > 0 && (q.dayHigh <= 0 || bh > q.dayHigh)) {
      q.dayHigh = bh;
    }
    if (bl != null && bl > 0 && (q.dayLow <= 0 || bl < q.dayLow)) {
      q.dayLow = bl;
    }
  }

  int get _digits {
    final fromApi = _api?['digits'];
    if (fromApi is num) return fromApi.toInt();
    return _live?.digits ?? 5;
  }

  double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v');
  }

  String _fmt(double? v) {
    if (v == null || v <= 0) return '—';
    return v.toStringAsFixed(_digits);
  }

  Future<void> _openWeb() async {
    final sym = widget.symbol.toLowerCase();
    await launchUrl(
      Uri.parse('https://www.mql5.com/en/quotes/currencies/$sym'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    double? pick(double liveV, dynamic apiV) {
      if (liveV > 0) return liveV;
      final a = _num(apiV);
      if (a != null && a > 0) return a;
      return null;
    }

    final bid = pick(live?.bid ?? 0, _api?['bid']);
    final ask = pick(live?.ask ?? 0, _api?['ask']);
    final bidHigh = pick(live?.bidHigh ?? 0, _api?['bidHigh']);
    final bidLow = pick(live?.bidLow ?? 0, _api?['bidLow']);
    final askHigh = pick(live?.askHigh ?? 0, _api?['askHigh']);
    final askLow = pick(live?.askLow ?? 0, _api?['askLow']);
    final open = pick(live?.dayOpen ?? 0, _api?['open']);
    final close = pick(live?.dayClose ?? 0, _api?['close']);

    double? changePct = _num(_api?['priceChangePct']);
    if (live != null && live.hasPrice) {
      changePct = live.changePct;
    } else if (changePct == null &&
        bid != null &&
        close != null &&
        close > 0) {
      changePct = (bid - close) / close * 100;
    }

    final inactive = tradingService.isQuoteInactive(widget.symbol);

    return Scaffold(
      backgroundColor: MtColors.white,
      appBar: AppBar(
        backgroundColor: MtColors.white,
        surfaceTintColor: MtColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(
          widget.symbol.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Open symbol page',
            padding: const EdgeInsets.only(right: 12),
            onPressed: _openWeb,
            icon: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.black87,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                'assets/icons/property_search.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null && _api == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: MtColors.icon),
                    ),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              children: [
                _statRow('Bid', _fmt(bid), inactive: inactive),
                _statRow('Bid high', _fmt(bidHigh), inactive: inactive),
                _statRow('Bid low', _fmt(bidLow), inactive: inactive),
                _statRow('Ask', _fmt(ask), inactive: inactive),
                _statRow('Ask high', _fmt(askHigh), inactive: inactive),
                _statRow('Ask low', _fmt(askLow), inactive: inactive),
                _changeRow(changePct, inactive: inactive),
                _statRow('Open price', _fmt(open), inactive: inactive),
                _statRow('Close price', _fmt(close), inactive: inactive),
              ],
            ),
    );
  }

  Widget _statRow(String label, String value, {required bool inactive}) {
    final valueColor = inactive ? MtColors.textSecondary : MtColors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: MtColors.text,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _changeRow(double? pct, {required bool inactive}) {
    final has = pct != null && pct.isFinite;
    final down = has && pct < 0;
    final text = !has ? '—' : '${pct.toStringAsFixed(2)}%';
    final valueColor = inactive
        ? MtColors.textSecondary
        : (has ? (down ? MtColors.ask : MtColors.bid) : MtColors.text);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Icon(
            down ? Icons.arrow_drop_down : Icons.arrow_drop_up,
            size: 22,
            color: _green,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Price change',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: MtColors.text,
              ),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
