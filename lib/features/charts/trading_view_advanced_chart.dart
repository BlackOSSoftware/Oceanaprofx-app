import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme_controller.dart';
import '../../ui/theme/oceana_colors.dart';

/// TradingView **Advanced Chart** embed — native left drawing toolbar.
/// Used when user taps Draw (broker Lightweight chart stays the default).
class TradingViewAdvancedChart extends StatefulWidget {
  const TradingViewAdvancedChart({
    super.key,
    required this.symbol,
    this.interval = '1',
    this.style = '1',
    this.studies = const [],
    this.showSideToolbar = true,
    this.candleOverrides = const {},
  });

  final String symbol;
  final String interval;

  /// TradingView style: 0 bars, 1 candles, 2 line, 3 area, 8 heikin, 9 hollow.
  final String style;
  final List<String> studies;

  /// When true, TradingView left drawing toolbar is visible.
  final bool showSideToolbar;

  /// Candle / bar colour overrides (TradingView `overrides` map).
  final Map<String, String> candleOverrides;

  static String tvSymbol(String broker) {
    var s = broker.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
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

    if (s.endsWith('USDT') && s.length > 4) {
      return 'BINANCE:$s';
    }
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

  @override
  State<TradingViewAdvancedChart> createState() =>
      _TradingViewAdvancedChartState();
}

class _TradingViewAdvancedChartState extends State<TradingViewAdvancedChart> {
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
      '${widget.symbol}|${widget.interval}|${widget.style}|${widget.studies.join(',')}|${widget.showSideToolbar ? 'side' : 'noside'}|${widget.candleOverrides.values.join(',')}|${_dark ? 'd' : 'l'}';

  @override
  void didUpdateWidget(covariant TradingViewAdvancedChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _signature();
    if (next == _sig) return;
    _sig = next;
    setState(() => _loading = true);
    _web = _makeController();
  }

  WebViewController _makeController() {
    final tv = TradingViewAdvancedChart.tvSymbol(widget.symbol);
    final html = _html(
      tv,
      widget.interval,
      widget.style,
      widget.studies,
      dark: _dark,
      showSideToolbar: widget.showSideToolbar,
      candleOverrides: widget.candleOverrides,
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
    required bool showSideToolbar,
    required Map<String, String> candleOverrides,
  }) {
    final sym = tvSymbol.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final iv = interval.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final st = style.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    final studiesJson = jsonEncode(studies);
    final overridesJson = jsonEncode(candleOverrides);
    final theme = dark ? 'dark' : 'light';
    final pageBg = dark ? '#1A1A1E' : '#ffffff';
    final chartBg = dark ? 'rgba(26, 26, 30, 1)' : 'rgba(255, 255, 255, 1)';
    final hideSide = showSideToolbar ? 'false' : 'true';
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
      "hide_side_toolbar": $hideSide,
      "allow_symbol_change": false,
      "save_image": false,
      "calendar": false,
      "hide_volume": true,
      "support_host": "https://www.tradingview.com",
      "studies": $studiesJson,
      "overrides": $overridesJson,
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
