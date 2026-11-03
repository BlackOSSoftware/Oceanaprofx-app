import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme_controller.dart';
import '../../ui/theme/oceana_colors.dart';

/// TradingView Advanced Chart — side tools closed, volume off.
/// Top chrome hidden; Flutter toolbar matches screenshot (TF / Indicators).
class TradingViewChart extends StatefulWidget {
  const TradingViewChart({
    super.key,
    required this.symbol,
    this.interval = '1',
    this.style = '1',
    this.studies = const [],
  });

  final String symbol;
  final String interval;
  /// TradingView style: 0 bars, 1 candles, 2 line, 3 area, 8 heikin, 9 hollow.
  final String style;
  final List<String> studies;

  static String tvSymbol(String broker) {
    var s = broker.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    // Strip common broker suffixes (e.g. BTCUSDT.m / BTCUSD#)
    s = s.replaceAll(RegExp(r'(M|PRO|ECN|RAW)$'), '');

    const map = <String, String>{
      'EURUSD': 'FX_IDC:EURUSD',
      'GBPUSD': 'FX_IDC:GBPUSD',
      'USDJPY': 'FX_IDC:USDJPY',
      'USDCHF': 'FX_IDC:USDCHF',
      'AUDUSD': 'FX_IDC:AUDUSD',
      'USDCAD': 'FX_IDC:USDCAD',
      'NZDUSD': 'FX_IDC:NZDUSD',
      'EURGBP': 'FX_IDC:EURGBP',
      'EURJPY': 'FX_IDC:EURJPY',
      'GBPJPY': 'FX_IDC:GBPJPY',
      'XAUUSD': 'OANDA:XAUUSD',
      'GOLD': 'OANDA:XAUUSD',
      'XAGUSD': 'OANDA:XAGUSD',
      'SILVER': 'OANDA:XAGUSD',
      // Crypto — broker may send BTCUSD or BTCUSDT
      'BTCUSD': 'BINANCE:BTCUSDT',
      'BTCUSDT': 'BINANCE:BTCUSDT',
      'ETHUSD': 'BINANCE:ETHUSDT',
      'ETHUSDT': 'BINANCE:ETHUSDT',
      'BNBUSD': 'BINANCE:BNBUSDT',
      'BNBUSDT': 'BINANCE:BNBUSDT',
      'SOLUSD': 'BINANCE:SOLUSDT',
      'SOLUSDT': 'BINANCE:SOLUSDT',
      'XRPUSD': 'BINANCE:XRPUSDT',
      'XRPUSDT': 'BINANCE:XRPUSDT',
      'ADAUSD': 'BINANCE:ADAUSDT',
      'ADAUSDT': 'BINANCE:ADAUSDT',
      'DOGEUSD': 'BINANCE:DOGEUSDT',
      'DOGEUSDT': 'BINANCE:DOGEUSDT',
      'LTCUSD': 'BINANCE:LTCUSDT',
      'LTCUSDT': 'BINANCE:LTCUSDT',
      'US30': 'FOREXCOM:US30',
      'US500': 'FOREXCOM:US500',
      'NAS100': 'FOREXCOM:NSXUSD',
      'UK100': 'FOREXCOM:UK100',
      'GER40': 'FOREXCOM:GER40',
      'DE40': 'FOREXCOM:GER40',
    };
    if (map.containsKey(s)) return map[s]!;

    // Any *USDT pair → Binance (TradingView has no FX_IDC crypto).
    if (s.endsWith('USDT') && s.length > 4) {
      return 'BINANCE:$s';
    }
    // Crypto quoted as *USD (BTCUSD) → Binance *USDT
    const cryptoBases = {
      'BTC', 'ETH', 'BNB', 'SOL', 'XRP', 'ADA', 'DOGE', 'LTC', 'DOT',
      'AVAX', 'MATIC', 'LINK', 'UNI', 'ATOM', 'NEAR', 'APT', 'ARB', 'OP',
      'SHIB', 'TRX', 'TON', 'SUI', 'PEPE',
    };
    if (s.endsWith('USD') && !s.endsWith('USDT') && s.length > 3) {
      final base = s.substring(0, s.length - 3);
      if (cryptoBases.contains(base)) return 'BINANCE:${base}USDT';
    }

    if (s.length == 6 && RegExp(r'^[A-Z]{6}$').hasMatch(s)) {
      return 'FX_IDC:$s';
    }
    return 'FX_IDC:$s';
  }

  static String intervalFromCode(String code) {
    switch (code.toUpperCase()) {
      case 'M1':
        return '1';
      case 'M5':
        return '5';
      case 'M15':
        return '15';
      case 'M30':
        return '30';
      case 'H1':
        return '60';
      case 'H2':
        return '120';
      case 'H4':
        return '240';
      case 'D1':
        return 'D';
      case 'W1':
        return 'W';
      case 'MN':
        return 'M';
      default:
        return '1';
    }
  }

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  late WebViewController _web;
  var _loading = true;
  String _sig = '';
  var _dark = false;

  @override
  void initState() {
    super.initState();
    _dark = mtDarkMode.value;
    _sig = _signature();
    _web = _makeController();
    mtDarkMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    mtDarkMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    final dark = mtDarkMode.value;
    if (dark == _dark) return;
    _dark = dark;
    _sig = _signature();
    setState(() => _loading = true);
    _web = _makeController();
  }

  String _signature() =>
      '${widget.symbol}|${widget.interval}|${widget.style}|${widget.studies.join(',')}|${_dark ? 'd' : 'l'}';

  @override
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _signature();
    if (next == _sig) return;
    _sig = next;
    setState(() => _loading = true);
    _web = _makeController();
  }

  WebViewController _makeController() {
    final tv = TradingViewChart.tvSymbol(widget.symbol);
    final html = _html(
      tv,
      widget.interval,
      widget.style,
      widget.studies,
      dark: _dark,
    );
    final bg = _dark ? const Color(0xFF1A1A1E) : Colors.white;
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: 'https://www.tradingview.com/');
  }

  static String _html(
    String tvSymbol,
    String interval,
    String style,
    List<String> studies, {
    required bool dark,
  }) {
    final sym = tvSymbol.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final iv = interval.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final st = style.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final studiesJson = jsonEncode(studies);
    final theme = dark ? 'dark' : 'light';
    final pageBg = dark ? '#1A1A1E' : '#ffffff';
    final chartBg = dark ? 'rgba(26, 26, 30, 1)' : 'rgba(255, 255, 255, 1)';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <style>
    html, body { margin:0; padding:0; width:100%; height:100%; background:$pageBg; overflow:hidden; }
    .tradingview-widget-container, .tradingview-widget-container__widget {
      width:100%; height:100%;
    }
  </style>
</head>
<body>
  <div class="tradingview-widget-container" style="height:100%;width:100%">
    <div class="tradingview-widget-container__widget" style="height:100%;width:100%"></div>
    <script type="text/javascript" src="https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js" async>
    {
      "autosize": true,
      "symbol": "$sym",
      "interval": "$iv",
      "timezone": "Etc/UTC",
      "theme": "$theme",
      "style": "$st",
      "locale": "en",
      "backgroundColor": "$chartBg",
      "hide_top_toolbar": true,
      "hide_legend": false,
      "hide_side_toolbar": true,
      "allow_symbol_change": false,
      "save_image": false,
      "calendar": false,
      "hide_volume": true,
      "support_host": "https://www.tradingview.com",
      "studies": $studiesJson,
      "disabled_features": [
        "create_volume_indicator_by_default",
        "volume_force_overlay",
        "header_widget"
      ]
    }
    </script>
  </div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: WebViewWidget(
            controller: _web,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
        ),
        if (_loading)
          ColoredBox(
            color: OcColors.surface,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
