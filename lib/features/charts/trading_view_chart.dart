import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme_controller.dart';
import '../../core/trading_service.dart';
import '../../ui/theme/oceana_colors.dart';
import 'chart_models.dart';
import 'chart_repository.dart';

/// TradingView **Lightweight Charts** — TV look, broker OHLC + live bid,
/// plus built-in indicators (SMA/EMA/BB/RSI/MACD/…).
class TradingViewChart extends StatefulWidget {
  const TradingViewChart({
    super.key,
    required this.symbol,
    this.timeframe = 'M1',
    this.interval = '1',
    this.style = '1',
    this.studies = const [],
    this.active = true,
  });

  final String symbol;
  final String timeframe;
  final String interval;
  final String style;

  /// Indicator ids from [ChartIndicator.catalog] (e.g. rsi, sma20, macd).
  final List<String> studies;
  final bool active;

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

  static int secondsFor(String code) => ChartTimeframes.of(code).seconds;

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  late WebViewController _web;
  var _loading = true;
  var _pageReady = false;
  var _dark = false;
  String _sig = '';
  double? _lastTick;

  final _repo = const ChartRepository();

  @override
  void initState() {
    super.initState();
    _dark = mtDarkMode.value;
    _sig = _signature();
    _web = _makeController();
    mtDarkMode.addListener(_onThemeChanged);
    tradingService.ensureSubscribed(widget.symbol);
    tradingService.addListener(_onLive);
  }

  @override
  void dispose() {
    mtDarkMode.removeListener(_onThemeChanged);
    tradingService.removeListener(_onLive);
    super.dispose();
  }

  String _signature() =>
      '${widget.symbol}|${widget.timeframe}|${widget.style}|${_dark ? 'd' : 'l'}';

  void _onThemeChanged() {
    if (!mounted) return;
    final dark = mtDarkMode.value;
    if (dark == _dark) return;
    _dark = dark;
    _reload();
  }

  @override
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      tradingService.ensureSubscribed(widget.symbol);
    }
    final next = _signature();
    if (next != _sig) {
      _sig = next;
      _reload();
      return;
    }
    if (!_listEq(oldWidget.studies, widget.studies) && _pageReady) {
      _pushIndicators();
    }
    // IndexedStack keeps WebView alive — while inactive, ticks are skipped so
    // candles drift from live price. Resync OHLC + tick when chart tab returns.
    if (!oldWidget.active && widget.active && _pageReady) {
      unawaited(_resyncFromServer());
    }
  }

  /// Reload candles from API and snap to current bid (after background tab).
  Future<void> _resyncFromServer() async {
    if (!mounted || !_pageReady || !widget.active) return;
    await _pushHistory();
    if (!mounted || !_pageReady || !widget.active) return;
    await _pushIndicators();
    _pushLiveTick(force: true);
  }

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _reload() {
    _pageReady = false;
    _lastTick = null;
    setState(() => _loading = true);
    _web = _makeController();
  }

  WebViewController _makeController() {
    final bg = _dark ? const Color(0xFF1A1A1E) : Colors.white;
    final tfSec = TradingViewChart.secondsFor(widget.timeframe);
    final html = _html(
      dark: _dark,
      style: widget.style,
      tfSeconds: tfSec,
    );
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            _pageReady = true;
            await _pushHistory();
            await _pushIndicators();
            if (mounted) setState(() => _loading = false);
            _pushLiveTick(force: true);
          },
        ),
      )
      ..loadHtmlString(html, baseUrl: 'https://www.tradingview.com/');
  }

  Future<void> _pushHistory() async {
    if (!_pageReady) return;
    try {
      final page = await _repo.candles(
        symbol: widget.symbol,
        timeframe: widget.timeframe,
        limit: 300,
      );
      if (!mounted || !_pageReady) return;
      final bars = [
        for (final c in page.candles)
          {
            'time': c.t,
            'open': c.o,
            'high': c.h,
            'low': c.l,
            'close': c.c,
            'volume': c.v,
          },
      ];
      final digits = page.digits ?? 5;
      await _web.runJavaScript(
        'window.__setBars(${jsonEncode(bars)}, $digits);',
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      await _web.runJavaScript(
        'window.__setError(${jsonEncode(msg)});',
      );
    }
  }

  Future<void> _pushIndicators() async {
    if (!_pageReady) return;
    try {
      await _web.runJavaScript(
        'window.__setIndicators(${jsonEncode(widget.studies)});',
      );
    } catch (_) {}
  }

  void _onLive() {
    if (!widget.active || !_pageReady) return;
    _pushLiveTick();
  }

  void _pushLiveTick({bool force = false}) {
    final q = tradingService.quoteFor(widget.symbol);
    if (q == null || !q.hasPrice) return;
    if (!force && _lastTick == q.bid) return;
    _lastTick = q.bid;
    final t = (q.time ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    _web.runJavaScript('window.__tick(${q.bid}, ${q.ask}, $t);');
  }

  static String _html({
    required bool dark,
    required String style,
    required int tfSeconds,
  }) {
    final pageBg = dark ? '#1A1A1E' : '#ffffff';
    final textColor = dark ? '#D1D4DC' : '#111111';
    final gridColor = dark ? '#2A2A32' : '#E6E6EA';
    final borderColor = dark ? '#3A3A44' : '#D0D0D6';
    final seriesKind = switch (style) {
      '2' => 'line',
      '3' => 'area',
      _ => 'candle',
    };
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
  <script src="https://unpkg.com/lightweight-charts@4.2.0/dist/lightweight-charts.standalone.production.js"></script>
  <style>
    html, body { margin:0; padding:0; width:100%; height:100%; background:$pageBg; overflow:hidden; }
    #c { width:100%; height:100%; }
    #err {
      display:none; position:absolute; inset:0; align-items:center; justify-content:center;
      color:$textColor; font:14px/1.4 -apple-system,BlinkMacSystemFont,sans-serif; padding:24px; text-align:center;
    }
  </style>
</head>
<body>
  <div id="c"></div>
  <div id="err"></div>
  <script>
(function() {
  var kind = ${jsonEncode(seriesKind)};
  var tfSec = $tfSeconds;
  var digits = 5;
  var ohlc = [];
  var lastBar = null;
  var bidLine = null;
  var askLine = null;
  var activeIds = [];
  var indSeries = {};

  var chart = LightweightCharts.createChart(document.getElementById('c'), {
    autoSize: true,
    layout: { background: { color: '$pageBg' }, textColor: '$textColor', fontSize: 11 },
    grid: { vertLines: { color: '$gridColor' }, horzLines: { color: '$gridColor' } },
    rightPriceScale: {
      borderColor: '$borderColor',
      scaleMargins: { top: 0.08, bottom: 0.12 },
      autoScale: true,
      mode: 0,
      invertScale: false,
      alignLabels: true,
      borderVisible: true,
      entireTextOnly: false,
      visible: true,
      // Forex <1 (AUDCAD…) needs room for 5dp labels.
      minimumWidth: 78
    },
    timeScale: {
      borderColor: '$borderColor',
      timeVisible: true,
      secondsVisible: tfSec < 300,
      barSpacing: 7,
      minBarSpacing: 2,
      rightOffset: 5
    },
    crosshair: { mode: LightweightCharts.CrosshairMode.Normal },
    // Price-axis drag / pinch must stay ON (was blocking scale from the right).
    handleScale: {
      axisPressedMouseMove: { time: true, price: true },
      axisTouch: true,
      mouseWheel: true,
      pinch: true
    },
    handleScroll: {
      mouseWheel: true,
      pressedMouseMove: true,
      horzTouchDrag: true,
      vertTouchDrag: true
    }
  });
  var lastPaneCount = -1;

  function priceFormatFor(dig) {
    var d = Math.max(2, Math.min(8, (dig | 0) || 5));
    return {
      type: 'price',
      precision: d,
      minMove: Math.pow(10, -d)
    };
  }

  function applyPriceFormat(dig) {
    digits = Math.max(2, Math.min(8, (dig | 0) || 5));
    series.applyOptions({ priceFormat: priceFormatFor(digits) });
  }

  /** Drop bad/zero OHLC that blow out the Y scale (common on FX < 1). */
  function sanitizeBar(b) {
    if (!b) return null;
    var o = Number(b.open), h = Number(b.high), l = Number(b.low), c = Number(b.close);
    if (!(o > 0 && h > 0 && l > 0 && c > 0)) return null;
    if (!isFinite(o) || !isFinite(h) || !isFinite(l) || !isFinite(c)) return null;
    var hi = Math.max(o, h, l, c);
    var lo = Math.min(o, h, l, c);
    // Reject absurd spikes vs typical FX/crypto ranges for a single bar.
    if (hi / lo > 50) return null;
    return {
      time: b.time,
      open: o,
      high: hi,
      low: lo,
      close: c,
      volume: Number(b.volume) || 0
    };
  }

  /** Re-enable autoscaling after symbol/TF change (manual drag turns it off). */
  function resetPriceScale() {
    try {
      chart.priceScale('right').applyOptions({
        autoScale: true,
        scaleMargins: { top: 0.08, bottom: Math.min(0.55, 0.12 + Math.max(0, lastPaneCount) * 0.14) }
      });
      series.priceScale().applyOptions({ autoScale: true });
    } catch (e) {}
  }

  var series;
  if (kind === 'line') {
    series = chart.addLineSeries({
      color: '#1414C7', lineWidth: 2, lastValueVisible: true, priceLineVisible: false,
      priceFormat: priceFormatFor(digits)
    });
  } else if (kind === 'area') {
    series = chart.addAreaSeries({
      lineColor: '#1414C7', topColor: 'rgba(20,20,199,0.28)', bottomColor: 'rgba(20,20,199,0.02)',
      lineWidth: 2, lastValueVisible: true, priceLineVisible: false,
      priceFormat: priceFormatFor(digits)
    });
  } else {
    series = chart.addCandlestickSeries({
      upColor: '#26A69A', downColor: '#EF5350', borderUpColor: '#26A69A', borderDownColor: '#EF5350',
      wickUpColor: '#26A69A', wickDownColor: '#EF5350', lastValueVisible: true, priceLineVisible: false,
      priceFormat: priceFormatFor(digits)
    });
  }

  function toSeriesBar(b) {
    if (kind === 'candle') return { time: b.time, open: b.open, high: b.high, low: b.low, close: b.close };
    return { time: b.time, value: b.close };
  }

  function closes() { return ohlc.map(function(b){ return b.close; }); }
  function sma(arr, len) {
    var out = [];
    var sum = 0;
    for (var i = 0; i < arr.length; i++) {
      sum += arr[i];
      if (i >= len) sum -= arr[i - len];
      out.push(i >= len - 1 ? sum / len : null);
    }
    return out;
  }
  function ema(arr, len) {
    var out = [];
    var k = 2 / (len + 1);
    var prev = null;
    for (var i = 0; i < arr.length; i++) {
      if (arr[i] == null) { out.push(null); continue; }
      if (prev == null) {
        if (i < len - 1) { out.push(null); continue; }
        var s = 0;
        for (var j = i - len + 1; j <= i; j++) s += arr[j];
        prev = s / len;
        out.push(prev);
      } else {
        prev = arr[i] * k + prev * (1 - k);
        out.push(prev);
      }
    }
    return out;
  }
  function stdev(arr, len) {
    var out = [];
    for (var i = 0; i < arr.length; i++) {
      if (i < len - 1) { out.push(null); continue; }
      var mean = 0;
      for (var j = i - len + 1; j <= i; j++) mean += arr[j];
      mean /= len;
      var v = 0;
      for (var j = i - len + 1; j <= i; j++) v += (arr[j] - mean) * (arr[j] - mean);
      out.push(Math.sqrt(v / len));
    }
    return out;
  }
  function rsi(arr, len) {
    var out = [];
    for (var i = 0; i < arr.length; i++) out.push(null);
    if (arr.length <= len) return out;
    var gains = 0, losses = 0;
    for (var i = 1; i <= len; i++) {
      var d = arr[i] - arr[i - 1];
      if (d >= 0) gains += d; else losses -= d;
    }
    var ag = gains / len, al = losses / len;
    out[len] = al === 0 ? 100 : 100 - (100 / (1 + ag / al));
    for (var i = len + 1; i < arr.length; i++) {
      var d = arr[i] - arr[i - 1];
      var g = d > 0 ? d : 0;
      var l = d < 0 ? -d : 0;
      ag = (ag * (len - 1) + g) / len;
      al = (al * (len - 1) + l) / len;
      out[i] = al === 0 ? 100 : 100 - (100 / (1 + ag / al));
    }
    return out;
  }
  function trueRange(i) {
    if (i === 0) return ohlc[0].high - ohlc[0].low;
    var h = ohlc[i].high, l = ohlc[i].low, pc = ohlc[i - 1].close;
    return Math.max(h - l, Math.abs(h - pc), Math.abs(l - pc));
  }
  function atr(len) {
    var trs = [];
    for (var i = 0; i < ohlc.length; i++) trs.push(trueRange(i));
    return sma(trs, len);
  }
  function lineData(vals) {
    var data = [];
    for (var i = 0; i < ohlc.length; i++) {
      if (vals[i] == null || !isFinite(vals[i])) continue;
      data.push({ time: ohlc[i].time, value: vals[i] });
    }
    return data;
  }
  function clearIndicators() {
    Object.keys(indSeries).forEach(function(k) {
      try { chart.removeSeries(indSeries[k]); } catch (e) {}
    });
    indSeries = {};
  }
  function paneMargins(paneCount) {
    // Only when pane count changes — re-applying every tick resets
    // manual price-scale zoom from the right axis.
    if (paneCount === lastPaneCount) return;
    lastPaneCount = paneCount;
    var bottom = Math.min(0.55, 0.12 + paneCount * 0.14);
    chart.priceScale('right').applyOptions({
      scaleMargins: { top: 0.04, bottom: bottom }
    });
  }

  /** Sort, align to TF buckets, dedupe, fill tiny holes (missed ticks). */
  function normalizeBars(bars) {
    if (!bars || !bars.length) return [];
    var map = {};
    for (var i = 0; i < bars.length; i++) {
      var b = bars[i];
      var t = Math.floor(Number(b.time) / tfSec) * tfSec;
      if (!isFinite(t)) continue;
      var clean = sanitizeBar({
        time: t,
        open: b.open,
        high: b.high,
        low: b.low,
        close: b.close,
        volume: b.volume
      });
      if (clean) map[t] = clean;
    }
    var times = Object.keys(map).map(Number).sort(function(a, b) { return a - b; });
    var out = [];
    for (var i = 0; i < times.length; i++) {
      var t = times[i];
      if (out.length) {
        var prev = out[out.length - 1];
        var gap = Math.round((t - prev.time) / tfSec);
        // Fill 1–3 missing bars only (feed hiccups). Weekend/session
        // gaps stay — otherwise fake candles appear.
        if (gap > 1 && gap <= 4) {
          for (var g = 1; g < gap; g++) {
            var px = prev.close;
            out.push({
              time: prev.time + g * tfSec,
              open: px, high: px, low: px, close: px, volume: 0
            });
          }
        }
      }
      out.push(map[t]);
    }
    // Drop global outliers that stretch the Y axis (bad ticks / bad merge).
    if (out.length >= 8) {
      var mids = out.map(function(x) { return (x.high + x.low) / 2; }).sort(function(a, b) { return a - b; });
      var med = mids[Math.floor(mids.length / 2)];
      if (med > 0) {
        out = out.filter(function(x) {
          return x.high < med * 8 && x.low > med / 8;
        });
      }
    }
    return out;
  }
  function addOverlayLine(id, color, data, width) {
    var s = chart.addLineSeries({
      color: color, lineWidth: width || 2, priceLineVisible: false,
      lastValueVisible: false, crosshairMarkerVisible: false
    });
    s.setData(data);
    indSeries[id] = s;
  }
  function addPaneLine(id, color, data, scaleId, top, bottom) {
    var s = chart.addLineSeries({
      color: color, lineWidth: 2, priceScaleId: scaleId,
      priceLineVisible: false, lastValueVisible: true
    });
    s.setData(data);
    chart.priceScale(scaleId).applyOptions({
      scaleMargins: { top: top, bottom: bottom },
      borderVisible: false
    });
    indSeries[id] = s;
  }
  function addPaneHist(id, data, scaleId, top, bottom) {
    var s = chart.addHistogramSeries({
      priceScaleId: scaleId, priceLineVisible: false, lastValueVisible: false
    });
    s.setData(data);
    chart.priceScale(scaleId).applyOptions({
      scaleMargins: { top: top, bottom: bottom },
      borderVisible: false
    });
    indSeries[id] = s;
  }

  function applyIndicators() {
    clearIndicators();
    if (!ohlc.length || !activeIds.length) {
      paneMargins(0);
      return;
    }
    var c = closes();
    var panes = [];
    activeIds.forEach(function(id) {
      if (id === 'vol' || id === 'rsi' || id === 'macd' || id === 'stoch' ||
          id === 'atr' || id === 'mom' || id === 'cci' || id === 'willr' || id === 'ao') {
        panes.push(id);
      }
    });
    paneMargins(panes.length);
    var paneH = panes.length ? (0.55 / panes.length) : 0;

    activeIds.forEach(function(id) {
      if (id === 'sma20') addOverlayLine('sma20', '#F5A623', lineData(sma(c, 20)));
      else if (id === 'sma50') addOverlayLine('sma50', '#9B59B6', lineData(sma(c, 50)));
      else if (id === 'ema20') addOverlayLine('ema20', '#3498DB', lineData(ema(c, 20)));
      else if (id === 'ema50') addOverlayLine('ema50', '#E67E22', lineData(ema(c, 50)));
      else if (id === 'bb') {
        var mid = sma(c, 20);
        var sd = stdev(c, 20);
        var up = [], lo = [], mi = [];
        for (var i = 0; i < ohlc.length; i++) {
          if (mid[i] == null || sd[i] == null) continue;
          mi.push({ time: ohlc[i].time, value: mid[i] });
          up.push({ time: ohlc[i].time, value: mid[i] + 2 * sd[i] });
          lo.push({ time: ohlc[i].time, value: mid[i] - 2 * sd[i] });
        }
        addOverlayLine('bb_mid', '#787B86', mi, 1);
        addOverlayLine('bb_up', '#2196F3', up, 1);
        addOverlayLine('bb_lo', '#2196F3', lo, 1);
      } else if (id === 'vol') {
        var pi = panes.indexOf('vol');
        var top = 1 - (pi + 1) * paneH + 0.02;
        var bot = Math.max(0, 1 - (pi + 1) * paneH - paneH + 0.04);
        // invert: scaleMargins top is from top of chart
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        var hist = [];
        for (var i = 0; i < ohlc.length; i++) {
          var v = ohlc[i].volume || 0;
          if (!(v > 0)) v = Math.abs(ohlc[i].close - ohlc[i].open) * 1000 + 1;
          hist.push({
            time: ohlc[i].time,
            value: v,
            color: ohlc[i].close >= ohlc[i].open ? 'rgba(38,166,154,0.55)' : 'rgba(239,83,80,0.55)'
          });
        }
        addPaneHist('vol', hist, 'vol', t, b);
      } else if (id === 'rsi') {
        var pi = panes.indexOf('rsi');
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        addPaneLine('rsi', '#7B1FA2', lineData(rsi(c, 14)), 'rsi', t, b);
      } else if (id === 'macd') {
        var pi = panes.indexOf('macd');
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        var e12 = ema(c, 12), e26 = ema(c, 26);
        var macdLine = [], signalSrc = [];
        for (var i = 0; i < c.length; i++) {
          if (e12[i] == null || e26[i] == null) { macdLine.push(null); signalSrc.push(null); }
          else { var m = e12[i] - e26[i]; macdLine.push(m); signalSrc.push(m); }
        }
        // build signal on non-null macd values carefully via ema of macdLine with nulls
        var sig = ema(macdLine.map(function(v){ return v == null ? 0 : v; }), 9);
        // zero early until both ready
        for (var i = 0; i < sig.length; i++) {
          if (macdLine[i] == null) sig[i] = null;
        }
        var hist = [];
        for (var i = 0; i < ohlc.length; i++) {
          if (macdLine[i] == null || sig[i] == null) continue;
          var h = macdLine[i] - sig[i];
          hist.push({ time: ohlc[i].time, value: h, color: h >= 0 ? 'rgba(38,166,154,0.6)' : 'rgba(239,83,80,0.6)' });
        }
        addPaneHist('macd_hist', hist, 'macd', t, b);
        addPaneLine('macd', '#2196F3', lineData(macdLine), 'macd', t, b);
        addPaneLine('macd_sig', '#FF9800', lineData(sig), 'macd', t, b);
      } else if (id === 'stoch') {
        var pi = panes.indexOf('stoch');
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        var kArr = [];
        for (var i = 0; i < ohlc.length; i++) {
          if (i < 13) { kArr.push(null); continue; }
          var hh = -Infinity, ll = Infinity;
          for (var j = i - 13; j <= i; j++) {
            if (ohlc[j].high > hh) hh = ohlc[j].high;
            if (ohlc[j].low < ll) ll = ohlc[j].low;
          }
          kArr.push(hh === ll ? 50 : ((ohlc[i].close - ll) / (hh - ll)) * 100);
        }
        var dArr = sma(kArr.map(function(v){ return v == null ? 0 : v; }), 3);
        for (var i = 0; i < dArr.length; i++) if (kArr[i] == null) dArr[i] = null;
        addPaneLine('stoch_k', '#2196F3', lineData(kArr), 'stoch', t, b);
        addPaneLine('stoch_d', '#FF9800', lineData(dArr), 'stoch', t, b);
      } else if (id === 'atr') {
        var pi = panes.indexOf('atr');
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        addPaneLine('atr', '#26A69A', lineData(atr(14)), 'atr', t, b);
      } else if (id === 'mom') {
        var pi = panes.indexOf('mom');
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        var mom = [];
        for (var i = 0; i < c.length; i++) {
          mom.push(i >= 10 ? c[i] - c[i - 10] : null);
        }
        addPaneLine('mom', '#E91E63', lineData(mom), 'mom', t, b);
      } else if (id === 'cci') {
        var pi = panes.indexOf('cci');
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        var tp = ohlc.map(function(x){ return (x.high + x.low + x.close) / 3; });
        var mid = sma(tp, 20);
        var cci = [];
        for (var i = 0; i < tp.length; i++) {
          if (mid[i] == null) { cci.push(null); continue; }
          var md = 0;
          for (var j = i - 19; j <= i; j++) md += Math.abs(tp[j] - mid[i]);
          md /= 20;
          cci.push(md === 0 ? 0 : (tp[i] - mid[i]) / (0.015 * md));
        }
        addPaneLine('cci', '#00BCD4', lineData(cci), 'cci', t, b);
      } else if (id === 'willr') {
        var pi = panes.indexOf('willr');
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        var wr = [];
        for (var i = 0; i < ohlc.length; i++) {
          if (i < 13) { wr.push(null); continue; }
          var hh = -Infinity, ll = Infinity;
          for (var j = i - 13; j <= i; j++) {
            if (ohlc[j].high > hh) hh = ohlc[j].high;
            if (ohlc[j].low < ll) ll = ohlc[j].low;
          }
          wr.push(hh === ll ? -50 : ((hh - ohlc[i].close) / (hh - ll)) * -100);
        }
        addPaneLine('willr', '#8BC34A', lineData(wr), 'willr', t, b);
      } else if (id === 'ao') {
        var pi = panes.indexOf('ao');
        var t = 0.45 + pi * paneH;
        var b = Math.max(0.02, 1 - (t + paneH - 0.02));
        var mid = ohlc.map(function(x){ return (x.high + x.low) / 2; });
        var s5 = sma(mid, 5), s34 = sma(mid, 34);
        var hist = [];
        var prev = null;
        for (var i = 0; i < ohlc.length; i++) {
          if (s5[i] == null || s34[i] == null) continue;
          var v = s5[i] - s34[i];
          hist.push({
            time: ohlc[i].time,
            value: v,
            color: (prev == null || v >= prev) ? 'rgba(38,166,154,0.7)' : 'rgba(239,83,80,0.7)'
          });
          prev = v;
        }
        addPaneHist('ao', hist, 'ao', t, b);
      }
    });
  }

  function ensureLines(bid, ask) {
    if (bidLine) series.removePriceLine(bidLine);
    if (askLine) series.removePriceLine(askLine);
    bidLine = series.createPriceLine({
      price: bid, color: '#D1432A', lineWidth: 1,
      lineStyle: LightweightCharts.LineStyle.Solid, axisLabelVisible: true, title: ''
    });
    askLine = series.createPriceLine({
      price: ask, color: '#1F7A38', lineWidth: 1,
      lineStyle: LightweightCharts.LineStyle.Dotted, axisLabelVisible: true, title: ''
    });
  }

  window.__setBars = function(bars, dig) {
    document.getElementById('err').style.display = 'none';
    applyPriceFormat(typeof dig === 'number' && dig > 0 ? dig : digits);
    lastPaneCount = -1;
    ohlc = normalizeBars(bars || []);
    if (!ohlc.length) {
      series.setData([]);
      lastBar = null;
      clearIndicators();
      return;
    }
    series.setData(ohlc.map(toSeriesBar));
    lastBar = ohlc[ohlc.length - 1];
    // Symbol/TF change: always re-fit — previous pair's manual zoom
    // left autoScale off so AUDCAD (<1) looked "far" on the Y axis.
    resetPriceScale();
    chart.timeScale().fitContent();
    applyIndicators();
    resetPriceScale();
  };

  window.__setIndicators = function(ids) {
    activeIds = Array.isArray(ids) ? ids.slice() : [];
    lastPaneCount = -1;
    applyIndicators();
  };

  window.__setError = function(msg) {
    var el = document.getElementById('err');
    el.style.display = 'flex';
    el.textContent = msg || 'Failed to load chart';
  };

  window.__tick = function(bid, ask, timeSec) {
    if (!(bid > 0)) return;
    var t = Math.floor(timeSec);
    var bucket = Math.floor(t / tfSec) * tfSec;
    if (!lastBar) {
      lastBar = { time: bucket, open: bid, high: bid, low: bid, close: bid, volume: 0 };
      ohlc = [lastBar];
      series.setData([toSeriesBar(lastBar)]);
    } else if (bucket > lastBar.time) {
      var steps = Math.round((bucket - lastBar.time) / tfSec);
      // Bridge short holes so candles don't jump with empty space.
      if (steps > 1 && steps <= 4) {
        for (var s = 1; s < steps; s++) {
          var px = lastBar.close;
          var fill = {
            time: lastBar.time + s * tfSec,
            open: px, high: px, low: px, close: px, volume: 0
          };
          ohlc.push(fill);
          series.update(toSeriesBar(fill));
          lastBar = fill;
        }
      }
      lastBar = { time: bucket, open: bid, high: bid, low: bid, close: bid, volume: 0 };
      ohlc.push(lastBar);
      series.update(toSeriesBar(lastBar));
    } else if (bucket === lastBar.time) {
      lastBar.close = bid;
      if (bid > lastBar.high) lastBar.high = bid;
      if (bid < lastBar.low) lastBar.low = bid;
      ohlc[ohlc.length - 1] = lastBar;
      series.update(toSeriesBar(lastBar));
    }
    ensureLines(bid, ask > 0 ? ask : bid);
    // Rare indicator refresh — frequent rebuild was resetting price zoom.
    var now = Date.now();
    if (activeIds.length && (!window.__indAt || now - window.__indAt > 2000)) {
      window.__indAt = now;
      applyIndicators();
    }
  };

  window.addEventListener('resize', function() {
    chart.applyOptions({ width: window.innerWidth, height: window.innerHeight });
  });
})();
  </script>
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
