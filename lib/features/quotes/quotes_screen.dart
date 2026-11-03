import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/mt_colors.dart';
import '../../core/shell_controller.dart';
import '../../core/trading_service.dart';
import '../../core/widgets/mt_header.dart';
import '../../core/widgets/quote_price.dart';
import '../shell/no_accounts_view.dart';
import '../shell/simple_page.dart';
import '../trade/new_order_page.dart';
import 'market_statistics_page.dart';
import 'quote_data.dart';
import 'selected_symbols_page.dart';

String _fmt(double v, int digits) => v.toStringAsFixed(digits);

(String, String) _split(double v, int digits) {
  final s = _fmt(v, digits);
  if (s.length <= 1) return (s, '');
  return (s.substring(0, s.length - 1), s.substring(s.length - 1));
}

String _timeStr(DateTime? t) {
  if (t == null) return '--:--:--';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// Build display quotes: live WS prices when available, static fallback.
List<Quote> liveDisplayQuotes() {
  final symbols = tradingService.watchlist.isNotEmpty
      ? tradingService.watchlist.map((w) => w.code).toList()
      : quotes.map((q) => q.symbol).toList();
  return [for (final sym in symbols) displayQuoteFor(sym)];
}

Quote displayQuoteFor(String symbol) => _displayQuote(symbol);

Quote _displayQuote(String symbol) {
  final fallback = quoteBySymbol(symbol);
  final live = tradingService.quoteFor(symbol);
  final inactive = tradingService.isQuoteInactive(symbol);
  // Live ticks na hon (weekend/closed) to bhi dayClose / dayOpen dikhao.
  if (live != null && !live.hasPrice) {
    final seed = live.dayClose > 0
        ? live.dayClose
        : (live.dayOpen > 0 ? live.dayOpen : 0.0);
    if (seed > 0) {
      live.bid = seed;
      live.ask = seed;
      live.prevBid = seed;
    }
  }
  if (live == null || !live.hasPrice) {
    final base =
        fallback ??
        Quote(
          symbol: symbol,
          change: '0 0.00%',
          changeUp: true,
          time: '--:--:--',
          spread: '0',
          bidHead: '0.00',
          bidTail: '0',
          askHead: '0.00',
          askTail: '0',
          low: '0',
          high: '0',
          priceUp: true,
          digits: 5,
          inactive: true,
        );
    // Last/static price dikhao lekin closed/no-tick pe gray.
    return Quote(
      symbol: base.symbol,
      change: base.change,
      changeUp: base.changeUp,
      time: base.time,
      spread: base.spread,
      bidHead: base.bidHead,
      bidTail: base.bidTail,
      askHead: base.askHead,
      askTail: base.askTail,
      low: base.low,
      high: base.high,
      priceUp: base.priceUp,
      digits: base.digits,
      inactive: true,
    );
  }
  final d = live.digits;
  final (bidHead, bidTail) = _split(live.bid, d);
  final (askHead, askTail) = _split(live.ask, d);
  return Quote(
    symbol: symbol,
    change: live.changeLabel,
    changeUp: live.changeUp,
    time: _timeStr(live.time),
    spread: '${live.spreadPoints}',
    bidHead: bidHead,
    bidTail: bidTail,
    askHead: askHead,
    askTail: askTail,
    low: _fmt(live.dayLow > 0 ? live.dayLow : live.bid, d),
    high: _fmt(live.dayHigh > 0 ? live.dayHigh : live.bid, d),
    priceUp: live.priceUp,
    digits: d,
    inactive: inactive,
  );
}

class QuotesScreen extends StatefulWidget {
  QuotesScreen({super.key, required this.onMenu});

  final VoidCallback onMenu;

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  bool _simpleView = false;
  String _accountKey = tradingService.accountKey;

  @override
  void initState() {
    super.initState();
    tradingService.addListener(_onTrading);
    // Subscribe after first frame — cold start pe kam kaam.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resubscribeQuotes();
    });
  }

  @override
  void dispose() {
    tradingService.removeListener(_onTrading);
    super.dispose();
  }

  void _onTrading() {
    final key = tradingService.accountKey;
    if (key == _accountKey) return;
    _accountKey = key;
    // New account: re-subscribe default symbols + account watchlist.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resubscribeQuotes();
    });
  }

  void _resubscribeQuotes() {
    for (final q in quotes) {
      tradingService.subscribe(q.symbol);
    }
    unawaited(tradingService.refreshWatchlist());
  }

  @override
  Widget build(BuildContext context) {
    // Header static rehta hai - live ticks par sirf list rebuild
    // hoti hai, warna har tick par poori screen rebuild hone se
    // scroll atakata tha.
    return ColoredBox(
      color: MtColors.white,
      child: Column(
        children: [
          MtHeader(
            title: 'Quotes',
            titleFontSize: 14,
            titleFontFamily: 'Roboto Condensed',
            // titleLetterSpacing:-0.3,
            titleHeightScale: 1.2,
            onMenu: widget.onMenu,
            actions: [
              MtIconButton(
                tooltip: 'Add',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AddSymbolsPage(),
                  ),
                ),
                icon: CustomPaint(
                  size: Size(28, 28),
                  painter: _ThinAddIconPainter(MtColors.iconDark),
                ),
              ),
              MtIconButton(
                tooltip: 'Edit',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SelectedSymbolsPage(),
                  ),
                ),
                icon: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    MtColors.iconDark,
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    'assets/icons/header_edit.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: _QuotesLiveArea(
              simpleView: _simpleView,
              onToggleSimple: (v) => setState(() => _simpleView = v),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quotes list area: live ticks par refresh hoti hai, LEKIN scroll
/// ke dauraan rebuild bilkul nahi hoti - finger/fling chalte waqt
/// ek bhi frame nahi rukta, isiliye scroll hamesha smooth rehta
/// hai. Scroll rukte hi fresh prices ek baar me aa jate hain.
class _QuotesLiveArea extends StatefulWidget {
  const _QuotesLiveArea({
    required this.simpleView,
    required this.onToggleSimple,
  });

  final bool simpleView;
  final ValueChanged<bool> onToggleSimple;

  @override
  State<_QuotesLiveArea> createState() => _QuotesLiveAreaState();
}

class _QuotesLiveAreaState extends State<_QuotesLiveArea> {
  bool _scrolling = false;
  bool _dirtyWhileScrolling = false;

  @override
  void initState() {
    super.initState();
    tradingService.addListener(_onService);
  }

  @override
  void dispose() {
    tradingService.removeListener(_onService);
    super.dispose();
  }

  void _onService() {
    if (!mounted) return;
    if (_scrolling) {
      // Scroll ke beech me rebuild = jank. Bas yaad rakho ke
      // naya data aaya hai; rukte hi refresh kar denge.
      _dirtyWhileScrolling = true;
      return;
    }
    setState(() {});
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _scrolling = true;
    } else if (n is ScrollEndNotification) {
      _scrolling = false;
      if (_dirtyWhileScrolling) {
        _dirtyWhileScrolling = false;
        setState(() {});
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!tradingService.hasAnyAccount) return const NoAccountsBody();
    final display = liveDisplayQuotes();
    final Widget list = widget.simpleView
        ? _SimpleQuotesView(
            displayQuotes: display,
            onToggleViewMode: () => widget.onToggleSimple(false),
          )
        : ListView.builder(
            // Neeche ek card jitni khaali jagah - last wala
            // (EURUSD) bottom nav ke upar pura dikhta hai.
            padding: const EdgeInsets.only(top: 2, bottom: 88),
            // Aage ke tiles pehle se bane rahen - scroll smooth.
            cacheExtent: 500,
            itemCount: display.length,
            itemBuilder: (context, index) {
              final quote = display[index];
              return _QuoteTile(
                key: ValueKey(quote.symbol),
                quote: quote,
                simpleView: false,
                onToggleViewMode: () => widget.onToggleSimple(true),
              );
            },
          );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: list,
    );
  }
}

String _symbolDescription(String symbol) {
  const descriptions = <String, String>{
    'EURUSD': 'Euro vs US Dollar',
    'GBPUSD': 'British Pound vs US Dollar',
    'USDCHF': 'US Dollar vs Swiss Franc',
    'USDJPY': 'US Dollar vs Japanese Yen',
    'USDCNH': 'US Dollar vs Chinese Yuan',
    'USDRUB': 'US Dollar vs Russian Ruble',
    'AUDUSD': 'Australian Dollar vs US Dollar',
    'NZDUSD': 'New Zealand Dollar vs US Dollar',
    'USDCAD': 'US Dollar vs Canadian Dollar',
    'USDSEK': 'US Dollar vs Swedish Krona',
  };
  return descriptions[symbol] ?? symbol;
}

void _showQuoteMenu(
  BuildContext context,
  Quote quote, {
  required bool simpleView,
  required VoidCallback onToggleViewMode,
}) {
  final shell = ShellScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: MtColors.white,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    shape: RoundedRectangleBorder(),
    builder: (sheetContext) {
      void close() => Navigator.of(sheetContext).pop();
      final items = <(String, VoidCallback)>[
        ('${quote.symbol}: ${_symbolDescription(quote.symbol)}', close),
        (
          'New Order',
          () {
            close();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NewOrderPage(
                  symbol: quote.symbol,
                  onOrderPlaced: () => shell.openTab(2),
                ),
              ),
            );
          },
        ),
        (
          'Chart',
          () {
            close();
            shell.openChart(quote.symbol);
          },
        ),
        (
          'Properties',
          () {
            close();
            _openSymbolInfo(context, quote, statistics: false);
          },
        ),
        (
          'Depth Of Market',
          () {
            close();
            _openDepth(context);
          },
        ),
        (
          'Market Statistics',
          () {
            close();
            _openSymbolInfo(context, quote, statistics: true);
          },
        ),
        (
          simpleView ? 'Advanced view mode' : 'Simple view mode',
          () {
            close();
            onToggleViewMode();
          },
        ),
      ];
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++)
              InkWell(
                onTap: items[i].$2,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Text(
                    items[i].$1,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      color: i == 0 ? MtColors.icon : MtColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void _openSymbolInfo(
  BuildContext context,
  Quote quote, {
  required bool statistics,
}) {
  final live = tradingService.quotes[quote.symbol];
  final d = live?.digits ?? quote.digits;
  if (!statistics) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SymbolPropertiesPage(
          symbol: quote.symbol,
          description: _symbolDescription(quote.symbol),
          digits: d,
          live: live,
        ),
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MarketStatisticsPage(
        symbol: quote.symbol,
        description: _symbolDescription(quote.symbol),
      ),
    ),
  );
}

class _SymbolPropertiesPage extends StatefulWidget {
  const _SymbolPropertiesPage({
    required this.symbol,
    required this.description,
    required this.digits,
    required this.live,
  });
  final String symbol;
  final String description;
  final int digits;
  final LiveQuote? live;

  @override
  State<_SymbolPropertiesPage> createState() => _SymbolPropertiesPageState();
}

class _SymbolPropertiesPageState extends State<_SymbolPropertiesPage> {
  late Future<Map<String, dynamic>> _property;
  bool _usdPerLot = true;
  String? _infoUrl;

  @override
  void initState() {
    super.initState();
    _property = tradingService.instrumentProperty(widget.symbol);
  }

  void _reload() {
    setState(() {
      _infoUrl = null;
      _property = tradingService.instrumentProperty(widget.symbol);
    });
  }

  Future<void> _openInfoUrl() async {
    final url =
        (_infoUrl != null && _infoUrl!.isNotEmpty)
            ? _infoUrl!
            : 'https://www.mql5.com/en/quotes/currencies/${widget.symbol.toLowerCase()}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  List<Map<String, String>> _pairs(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          {
            'label': '${item['label'] ?? item['day'] ?? item['range'] ?? ''}',
            'value':
                '${item['value'] ?? item['multiplier'] ?? item['session'] ?? ''}',
          },
    ];
  }

  void _captureInfoUrl(String? url) {
    if (url == null || url.isEmpty || url == _infoUrl) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || url == _infoUrl) return;
      setState(() => _infoUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.symbol,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.1,
            ),
          ),
          Text(
            widget.description,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              color: Colors.black54,
              height: 1.15,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Open symbol page',
          padding: const EdgeInsets.only(right: 12),
          onPressed: _openInfoUrl,
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
    body: FutureBuilder<Map<String, dynamic>>(
      future: _property,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, color: Colors.black45, size: 30),
                  const SizedBox(height: 12),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final page =
            (data['page'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        _captureInfoUrl('${page['infoUrl'] ?? ''}');

        final properties = _pairs(page['properties']);
        final swapRates = _pairs(page['swapRates']);
        final quotesSessions = _pairs(page['quotesSessions']);
        final tradesSessions = _pairs(page['tradesSessions']);
        final margin =
            (page['margin'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
        final marketBuy = _pairs(margin['marketBuy']);
        final marketSell = _pairs(margin['marketSell']);
        final marginType =
            '${margin['type'] ?? 'Floating, notional value per symbol, USD'}';

        if (properties.isEmpty) {
          return const Center(
            child: Text(
              'No property data',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _propertySection('PROPERTIES'),
            for (final row in properties)
              _propertyRow(row['label']!, row['value']!),
            _propertySection('SWAP RATES'),
            for (final row in swapRates)
              _propertyRow(row['label']!, row['value']!),
            _propertySection('MARGIN RATE: INITIAL / MAINTENANCE'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Show values in USD per lot',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  _MtPropertySwitch(
                    value: _usdPerLot,
                    onChanged: (v) => setState(() => _usdPerLot = v),
                  ),
                ],
              ),
            ),
            _propertyRow('Type', marginType),
            _propertyRow('Market buy', ''),
            for (final row in marketBuy)
              _marginBand(row['label']!, row['value']!),
            _propertyRow('Market sell', ''),
            for (final row in marketSell)
              _marginBand(row['label']!, row['value']!),
            _propertySection('QUOTES SESSIONS'),
            for (final row in quotesSessions)
              _propertyRow(row['label']!, row['value']!),
            _propertySection('TRADES SESSIONS'),
            for (final row in tradesSessions)
              _propertyRow(row['label']!, row['value']!),
          ],
        );
      },
    ),
  );
}

/// MT5-style switch: thin grey track + oversized blue thumb with soft shadow.
class _MtPropertySwitch extends StatelessWidget {
  const _MtPropertySwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const _blue = Color(0xFF2E6BE0);
  static const _track = Color(0xFFD6D6D6);
  static const double _width = 40;
  static const double _trackH = 14;
  static const double _thumb = 22;

  @override
  Widget build(BuildContext context) {
    final left = value ? (_width - _thumb) : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: _width,
        height: _thumb + 4,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Thin pill track (thumb se chhota height)
            Align(
              alignment: Alignment.center,
              child: Container(
                width: _width - 2,
                height: _trackH,
                decoration: BoxDecoration(
                  color: _track,
                  borderRadius: BorderRadius.circular(_trackH / 2),
                ),
              ),
            ),
            // Blue circle thumb — track se bada, soft shadow
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              left: left,
              top: 2,
              child: Container(
                width: _thumb,
                height: _thumb,
                decoration: BoxDecoration(
                  color: _blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _propertySection(String title) => Padding(
  padding: const EdgeInsets.only(top: 18),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            fontFamily: 'Roboto Condensed',
            height: 1.15,
          ),
        ),
      ),
      const SizedBox(height: 5),
      // Full-bleed under PROPERTIES / SWAP / … — right edge tak
      const Divider(height: 2, thickness: 2, color: Color(0xffe8e8e8)),
    ],
  ),
);

Widget _propertyRow(String label, String value) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // Label — left edge (Exchange, Sector, …)
      Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          color: Colors.black,
          height: 1.2,
        ),
      ),
      if (value.isNotEmpty) ...[
        const SizedBox(width: 16),
        // Value — pura right edge (XCCY, Currency, …), ek line
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              color: Colors.black,
              height: 1.2,
            ),
          ),
        ),
      ],
    ],
  ),
);

Widget _marginBand(String range, String value) => Padding(
  padding: const EdgeInsets.fromLTRB(28, 8, 16, 8),
  child: Row(
    children: [
      Expanded(
        child: Text(
          range,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: Colors.black,
            height: 1.2,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        value,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          color: Colors.black,
          height: 1.2,
        ),
      ),
    ],
  ),
);

void _openDepth(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SimplePage(
        title: 'Depth Of Market',
        child: Center(
          child: Text(
            'Coming Soon',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              color: MtColors.icon,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SimpleQuotesView extends StatelessWidget {
  _SimpleQuotesView({
    required this.displayQuotes,
    required this.onToggleViewMode,
  });

  final List<Quote> displayQuotes;
  final VoidCallback onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontFamily: 'Roboto',
      color: MtColors.text,
      fontSize: 18,
      fontWeight: FontWeight.w400,
      height: 1.2,
    );
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 12, 6),
          child: Row(
            children: [
              Expanded(child: Text('Symbol', style: headerStyle)),
              SizedBox(
                width: 100,
                child: Text(
                  'Bid',
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  'Ask',
                  textAlign: TextAlign.right,
                  style: headerStyle,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: 88),
            itemCount: displayQuotes.length,
            itemBuilder: (context, index) {
              return _SimpleQuoteTile(
                quote: displayQuotes[index],
                onToggleViewMode: onToggleViewMode,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SimpleQuoteTile extends StatelessWidget {
  _SimpleQuoteTile({required this.quote, required this.onToggleViewMode});

  final Quote quote;
  final VoidCallback onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    // Sirf bid/ask gray jab closed — symbol normal rahe.
    final priceColor = quote.inactive
        ? MtColors.textSecondary
        : (quote.priceUp ? MtColors.bid : MtColors.ask);
    final flagColor = _quoteFlagColor(quote);
    return Material(
      color: MtColors.white,
      child: InkWell(
        onTap: () => _showQuoteMenu(
          context,
          quote,
          simpleView: true,
          onToggleViewMode: onToggleViewMode,
        ),
        onLongPress: () => _showQuoteMenu(
          context,
          quote,
          simpleView: true,
          onToggleViewMode: onToggleViewMode,
        ),
        splashFactory: InkRipple.splashFactory,
        splashColor: MtColors.text.withValues(alpha: 0.22),
        highlightColor: MtColors.text.withValues(alpha: 0.10),
        child: Stack(
          children: [
            if (flagColor != null)
              Positioned(
                left: 0,
                top: 0,
                child: _QuoteCornerFlag(color: flagColor),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 11, 12, 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.symbol,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MtColors.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _SimplePrice(
                        price: '${quote.bidHead}${quote.bidTail}',
                        color: priceColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _SimplePrice(
                        price: '${quote.askHead}${quote.askTail}',
                        color: priceColor,
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
}

class _SimplePrice extends StatelessWidget {
  _SimplePrice({required this.price, required this.color});

  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final main = price.length > 1
        ? price.substring(0, price.length - 1)
        : price;
    final last = price.length > 1 ? price.substring(price.length - 1) : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          main,
          style: TextStyle(
            fontFamily: 'Roboto Condensed',
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        if (last.isNotEmpty)
          Text(
            last,
            style: TextStyle(
              fontFamily: 'Roboto Condensed',
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
      ],
    );
  }
}

/// Left corner ribbon — sirf jab is user ki us instrument pe trade/pending ho:
/// open pos profit → blue, loss → red, pending only → gray. Warna null (no flag).
Color? _quoteFlagColor(Quote quote) {
  final sym = quote.symbol;
  var hasPos = false;
  var posPnl = 0.0;
  for (final p in tradingService.positions.values) {
    if (TradingService.sameInstrument(p.symbol, sym)) {
      hasPos = true;
      posPnl += p.floatingPnL;
    }
  }
  if (hasPos) return posPnl >= 0 ? MtColors.bid : MtColors.ask;

  final hasPending = tradingService.pendings.values.any(
    (o) => TradingService.sameInstrument(o.symbol, sym),
  );
  if (hasPending) return MtColors.textSecondary;

  return null;
}

class _QuoteCornerFlag extends StatelessWidget {
  const _QuoteCornerFlag({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(11, 11),
      painter: _CornerFlagPainter(color),
    );
  }
}

class _CornerFlagPainter extends CustomPainter {
  const _CornerFlagPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CornerFlagPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({
    super.key,
    required this.quote,
    required this.simpleView,
    required this.onToggleViewMode,
  });

  final Quote quote;
  final bool simpleView;
  final VoidCallback onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    // Sirf bid / ask gray — change %, symbol, time normal colors.
    final changeColor = quote.changeUp ? MtColors.bid : MtColors.ask;
    final bidColor = quote.inactive ? MtColors.textSecondary : MtColors.bid;
    final askColor = quote.inactive ? MtColors.textSecondary : MtColors.ask;
    final flagColor = _quoteFlagColor(quote);
    return Material(
      color: MtColors.white,
      child: InkWell(
        onTap: () => _showQuoteMenu(
          context,
          quote,
          simpleView: simpleView,
          onToggleViewMode: onToggleViewMode,
        ),
        onLongPress: () => _showQuoteMenu(
          context,
          quote,
          simpleView: simpleView,
          onToggleViewMode: onToggleViewMode,
        ),
        splashFactory: InkRipple.splashFactory,
        splashColor: MtColors.text.withValues(alpha: 0.22),
        highlightColor: MtColors.text.withValues(alpha: 0.10),
        child: Stack(
          children: [
            if (flagColor != null)
              Positioned(
                left: 0,
                top: 0,
                child: _QuoteCornerFlag(color: flagColor),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Points/delta (-522) = light gray; percent = blue/red.
                        Builder(
                          builder: (_) {
                            final parts = quote.change.split(' ');
                            final left = parts.isNotEmpty ? parts.first : '';
                            final right = parts.length > 1
                                ? parts.skip(1).join(' ')
                                : '';
                            return Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: left,
                                    style: TextStyle(
                                      color: MtColors.textSecondary,
                                    ),
                                  ),
                                  if (right.isNotEmpty)
                                    TextSpan(
                                      text: ' $right',
                                      style: TextStyle(color: changeColor),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.1,
                                fontWeight: FontWeight.w400,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 1),
                        Text(
                          quote.symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: MtColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 5),
                        SizedBox(
                          height: 17,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  quote.time,
                                  style: TextStyle(
                                    color: MtColors.iconDark,
                                    fontSize: 14,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(width: 5),
                                ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    MtColors.iconDark,
                                    BlendMode.srcIn,
                                  ),
                                  child: Image.asset(
                                    'assets/icons/quote_mark.png',
                                    width: 12,
                                    height: 11,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  quote.spread,
                                  style: TextStyle(
                                    color: MtColors.iconDark,
                                    fontSize: 14,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _PriceColumn(
                              price: QuotePrice(
                                head: quote.bidHead,
                                tail: quote.bidTail,
                                color: bidColor,
                              ),
                              label: 'L: ${quote.low}',
                            ),
                            const SizedBox(width: 16),
                            _PriceColumn(
                              price: QuotePrice(
                                head: quote.askHead,
                                tail: quote.askTail,
                                color: askColor,
                              ),
                              label: 'H: ${quote.high}',
                            ),
                          ],
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
}

class _ThinAddIconPainter extends CustomPainter {
  const _ThinAddIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    const arm = 9.0;
    canvas.drawLine(center.translate(-arm, 0), center.translate(arm, 0), paint);
    canvas.drawLine(center.translate(0, -arm), center.translate(0, arm), paint);
  }

  @override
  bool shouldRepaint(covariant _ThinAddIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PriceColumn extends StatelessWidget {
  _PriceColumn({required this.price, required this.label});

  final Widget price;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        price,
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: MtColors.iconDark, fontSize: 14, height: 1.1),
        ),
      ],
    );
  }
}
