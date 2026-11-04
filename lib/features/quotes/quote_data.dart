import '../../core/trading_service.dart';

class Quote {
  const Quote({
    required this.symbol,
    required this.change,
    required this.changeUp,
    required this.time,
    required this.spread,
    required this.bidHead,
    required this.bidTail,
    required this.askHead,
    required this.askTail,
    required this.low,
    required this.high,
    required this.priceUp,
    required this.digits,
    this.inactive = false,
  });

  final String symbol;
  final String change;
  final bool changeUp;
  final String time;
  final String spread;
  final String bidHead;
  final String bidTail;
  final String askHead;
  final String askTail;
  final String low;
  final String high;
  final bool priceUp;
  final int digits;

  /// Market closed / no live quote → bid/ask gray (not blue/red).
  final bool inactive;

  double get base => double.parse(low);
}

const quotes = <Quote>[
  Quote(
    symbol: 'EURUSD',
    change: '-537 -0.48%',
    changeUp: false,
    time: '10:40:17',
    spread: '1',
    bidHead: '1.1205',
    bidTail: '0',
    askHead: '1.1205',
    askTail: '1',
    low: '1.12050',
    high: '1.12632',
    priceUp: false,
    digits: 5,
  ),
  Quote(
    symbol: 'GBPUSD',
    change: '-314 -0.24%',
    changeUp: false,
    time: '10:40:17',
    spread: '1',
    bidHead: '1.3243',
    bidTail: '4',
    askHead: '1.3243',
    askTail: '5',
    low: '1.32411',
    high: '1.32765',
    priceUp: false,
    digits: 5,
  ),
  Quote(
    symbol: 'USDCHF',
    change: '+79 0.10%',
    changeUp: true,
    time: '10:40:17',
    spread: '2',
    bidHead: '0.8323',
    bidTail: '8',
    askHead: '0.8324',
    askTail: '0',
    low: '0.83093',
    high: '0.83362',
    priceUp: true,
    digits: 5,
  ),
  Quote(
    symbol: 'USDJPY',
    change: '+247 0.16%',
    changeUp: true,
    time: '10:40:17',
    spread: '1',
    bidHead: '158.32',
    bidTail: '2',
    askHead: '158.32',
    askTail: '3',
    low: '158.045',
    high: '158.511',
    priceUp: true,
    digits: 3,
  ),
  Quote(
    symbol: 'USDCNH',
    change: '+533 0.08%',
    changeUp: true,
    time: '10:40:16',
    spread: '12',
    bidHead: '6.7065',
    bidTail: '6',
    askHead: '6.7066',
    askTail: '8',
    low: '6.69975',
    high: '6.70752',
    priceUp: true,
    digits: 5,
  ),
  Quote(
    symbol: 'USDRUB',
    change: '-164 -0.19%',
    changeUp: false,
    time: '10:34:32',
    spread: '1500',
    bidHead: '84.68',
    bidTail: '6',
    askHead: '86.18',
    askTail: '6',
    low: '84.600',
    high: '84.750',
    priceUp: false,
    digits: 3,
  ),
  Quote(
    symbol: 'AUDUSD',
    change: '-138 -0.20%',
    changeUp: false,
    time: '10:40:17',
    spread: '1',
    bidHead: '0.6969',
    bidTail: '0',
    askHead: '0.6969',
    askTail: '1',
    low: '0.69664',
    high: '0.69844',
    priceUp: false,
    digits: 5,
  ),
  Quote(
    symbol: 'NZDUSD',
    change: '-152 -0.27%',
    changeUp: false,
    time: '10:40:17',
    spread: '1',
    bidHead: '0.5607',
    bidTail: '9',
    askHead: '0.5608',
    askTail: '0',
    low: '0.56012',
    high: '0.56264',
    priceUp: true,
    digits: 5,
  ),
  Quote(
    symbol: 'USDCAD',
    change: '-84 -0.06%',
    changeUp: false,
    time: '10:40:17',
    spread: '1',
    bidHead: '1.4048',
    bidTail: '0',
    askHead: '1.4048',
    askTail: '1',
    low: '1.40412',
    high: '1.40520',
    priceUp: false,
    digits: 5,
  ),
  Quote(
    symbol: 'USDSEK',
    change: '+112 0.11%',
    changeUp: true,
    time: '10:40:17',
    spread: '80',
    bidHead: '9.9204',
    bidTail: '0',
    askHead: '9.9212',
    askTail: '0',
    low: '9.91850',
    high: '9.92200',
    priceUp: true,
    digits: 5,
  ),
];

Quote? quoteBySymbol(String symbol) {
  for (final quote in quotes) {
    if (quote.symbol == symbol) return quote;
  }
  return null;
}

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

/// Live WS prices when available, static fallback otherwise.
Quote displayQuoteFor(String symbol) {
  final fallback = quoteBySymbol(symbol);
  final live = tradingService.quoteFor(symbol);
  final inactive = tradingService.isQuoteInactive(symbol);
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
    final base = fallback ??
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
