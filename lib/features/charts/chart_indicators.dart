/// Built-in indicators for TradingView Lightweight Charts (broker OHLC).
class ChartIndicator {
  const ChartIndicator({
    required this.id,
    required this.label,
    required this.study,
    this.subtitle = '',
  });

  final String id;
  final String label;

  /// Kept for sheet compat (was TV study script name).
  final String study;
  final String subtitle;

  /// TV-style list — only ids implemented in [TradingViewChart] JS.
  static const catalog = <ChartIndicator>[
    ChartIndicator(
      id: 'vol',
      label: 'Volume',
      study: 'Volume',
      subtitle: 'Histogram',
    ),
    ChartIndicator(
      id: 'sma20',
      label: 'Moving Average',
      study: 'SMA',
      subtitle: 'SMA 20',
    ),
    ChartIndicator(
      id: 'sma50',
      label: 'Moving Average',
      study: 'SMA',
      subtitle: 'SMA 50',
    ),
    ChartIndicator(
      id: 'ema20',
      label: 'Moving Average Exponential',
      study: 'EMA',
      subtitle: 'EMA 20',
    ),
    ChartIndicator(
      id: 'ema50',
      label: 'Moving Average Exponential',
      study: 'EMA',
      subtitle: 'EMA 50',
    ),
    ChartIndicator(
      id: 'bb',
      label: 'Bollinger Bands',
      study: 'BB',
      subtitle: 'Length 20 · StdDev 2',
    ),
    ChartIndicator(
      id: 'rsi',
      label: 'Relative Strength Index',
      study: 'RSI',
      subtitle: 'RSI 14',
    ),
    ChartIndicator(
      id: 'macd',
      label: 'MACD',
      study: 'MACD',
      subtitle: '12 · 26 · 9',
    ),
    ChartIndicator(
      id: 'stoch',
      label: 'Stochastic',
      study: 'Stochastic',
      subtitle: '%K 14 · %D 3',
    ),
    ChartIndicator(
      id: 'atr',
      label: 'Average True Range',
      study: 'ATR',
      subtitle: 'ATR 14',
    ),
    ChartIndicator(
      id: 'mom',
      label: 'Momentum',
      study: 'Momentum',
      subtitle: 'Length 10',
    ),
    ChartIndicator(
      id: 'cci',
      label: 'Commodity Channel Index',
      study: 'CCI',
      subtitle: 'CCI 20',
    ),
    ChartIndicator(
      id: 'willr',
      label: 'Williams %R',
      study: 'Williams %R',
      subtitle: 'Length 14',
    ),
    ChartIndicator(
      id: 'ao',
      label: 'Awesome Oscillator',
      study: 'AO',
      subtitle: 'SMA 5 − SMA 34',
    ),
  ];
}
