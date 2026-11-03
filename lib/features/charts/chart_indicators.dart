/// TradingView Advanced Chart study catalog (`*@tv-basicstudies`).
class ChartIndicator {
  const ChartIndicator({
    required this.id,
    required this.study,
    required this.label,
  });

  final String id;
  final String study;
  final String label;

  /// Full SCRIPT NAME list (TradingView-style), alphabetical.
  static const catalog = <ChartIndicator>[
    ChartIndicator(
      id: '52w',
      study: 'PivotPointsHighLow@tv-basicstudies',
      label: '52 Week High/Low',
    ),
    ChartIndicator(
      id: 'ac',
      study: 'AwesomeOscillator@tv-basicstudies',
      label: 'Accelerator Oscillator',
    ),
    ChartIndicator(
      id: 'accd',
      study: 'ACCD@tv-basicstudies',
      label: 'Accumulation/Distribution',
    ),
    ChartIndicator(
      id: 'asi',
      study: 'VigorIndex@tv-basicstudies',
      label: 'Accumulative Swing Index',
    ),
    ChartIndicator(
      id: 'ad',
      study: 'ROC@tv-basicstudies',
      label: 'Advance/Decline',
    ),
    ChartIndicator(
      id: 'alma',
      study: 'MAExp@tv-basicstudies',
      label: 'Arnaud Legoux Moving Average',
    ),
    ChartIndicator(
      id: 'aroon',
      study: 'AROON@tv-basicstudies',
      label: 'Aroon',
    ),
    ChartIndicator(
      id: 'adx',
      study: 'DM@tv-basicstudies',
      label: 'Average Directional Index',
    ),
    ChartIndicator(
      id: 'adr',
      study: 'studyADR@tv-basicstudies',
      label: 'Average Day Range',
    ),
    ChartIndicator(
      id: 'atr',
      study: 'ATR@tv-basicstudies',
      label: 'Average True Range',
    ),
    ChartIndicator(
      id: 'ao',
      study: 'AwesomeOscillator@tv-basicstudies',
      label: 'Awesome Oscillator',
    ),
    ChartIndicator(
      id: 'bb',
      study: 'BB@tv-basicstudies',
      label: 'Bollinger Bands',
    ),
    ChartIndicator(
      id: 'bbp',
      study: 'BollingerBandsR@tv-basicstudies',
      label: 'Bollinger Bands %B',
    ),
    ChartIndicator(
      id: 'bbw',
      study: 'BollingerBandsWidth@tv-basicstudies',
      label: 'Bollinger Bands Width',
    ),
    ChartIndicator(
      id: 'cmf',
      study: 'CMF@tv-basicstudies',
      label: 'Chaikin Money Flow',
    ),
    ChartIndicator(
      id: 'cho',
      study: 'ChaikinOscillator@tv-basicstudies',
      label: 'Chaikin Oscillator',
    ),
    ChartIndicator(
      id: 'cmo',
      study: 'chandeMO@tv-basicstudies',
      label: 'Chande Momentum Oscillator',
    ),
    ChartIndicator(
      id: 'chop',
      study: 'ChoppinessIndex@tv-basicstudies',
      label: 'Choppiness Index',
    ),
    ChartIndicator(
      id: 'cci',
      study: 'CCI@tv-basicstudies',
      label: 'Commodity Channel Index',
    ),
    ChartIndicator(
      id: 'crsi',
      study: 'CRSI@tv-basicstudies',
      label: 'Connors RSI',
    ),
    ChartIndicator(
      id: 'dpo',
      study: 'DetrendedPriceOscillator@tv-basicstudies',
      label: 'Detrended Price Oscillator',
    ),
    ChartIndicator(
      id: 'donch',
      study: 'DONCH@tv-basicstudies',
      label: 'Donchian Channels',
    ),
    ChartIndicator(
      id: 'dema',
      study: 'DoubleEMA@tv-basicstudies',
      label: 'Double EMA',
    ),
    ChartIndicator(
      id: 'eom',
      study: 'EaseOfMovement@tv-basicstudies',
      label: 'Ease Of Movement',
    ),
    ChartIndicator(
      id: 'efi',
      study: 'EFI@tv-basicstudies',
      label: "Elder's Force Index",
    ),
    ChartIndicator(
      id: 'env',
      study: 'ENV@tv-basicstudies',
      label: 'Envelope',
    ),
    ChartIndicator(
      id: 'fisher',
      study: 'FisherTransform@tv-basicstudies',
      label: 'Fisher Transform',
    ),
    ChartIndicator(
      id: 'hv',
      study: 'HV@tv-basicstudies',
      label: 'Historical Volatility',
    ),
    ChartIndicator(
      id: 'hma',
      study: 'hullMA@tv-basicstudies',
      label: 'Hull Moving Average',
    ),
    ChartIndicator(
      id: 'ichi',
      study: 'IchimokuCloud@tv-basicstudies',
      label: 'Ichimoku Cloud',
    ),
    ChartIndicator(
      id: 'kelt',
      study: 'KLTNR@tv-basicstudies',
      label: 'Keltner Channels',
    ),
    ChartIndicator(
      id: 'kst',
      study: 'KST@tv-basicstudies',
      label: 'Know Sure Thing',
    ),
    ChartIndicator(
      id: 'linreg',
      study: 'LinearRegression@tv-basicstudies',
      label: 'Linear Regression',
    ),
    ChartIndicator(
      id: 'macd',
      study: 'MACD@tv-basicstudies',
      label: 'MACD',
    ),
    ChartIndicator(
      id: 'mom',
      study: 'MOM@tv-basicstudies',
      label: 'Momentum',
    ),
    ChartIndicator(
      id: 'mf',
      study: 'MF@tv-basicstudies',
      label: 'Money Flow',
    ),
    ChartIndicator(
      id: 'sma',
      study: 'MASimple@tv-basicstudies',
      label: 'Moving Average',
    ),
    ChartIndicator(
      id: 'ema',
      study: 'MAExp@tv-basicstudies',
      label: 'Moving Average Exponential',
    ),
    ChartIndicator(
      id: 'wma',
      study: 'MAWeighted@tv-basicstudies',
      label: 'Moving Average Weighted',
    ),
    ChartIndicator(
      id: 'obv',
      study: 'OBV@tv-basicstudies',
      label: 'On Balance Volume',
    ),
    ChartIndicator(
      id: 'psar',
      study: 'PSAR@tv-basicstudies',
      label: 'Parabolic SAR',
    ),
    ChartIndicator(
      id: 'pivot',
      study: 'PivotPointsStandard@tv-basicstudies',
      label: 'Pivot Points Standard',
    ),
    ChartIndicator(
      id: 'po',
      study: 'PriceOsc@tv-basicstudies',
      label: 'Price Oscillator',
    ),
    ChartIndicator(
      id: 'pvt',
      study: 'PriceVolumeTrend@tv-basicstudies',
      label: 'Price Volume Trend',
    ),
    ChartIndicator(
      id: 'roc',
      study: 'ROC@tv-basicstudies',
      label: 'Rate Of Change',
    ),
    ChartIndicator(
      id: 'rsi',
      study: 'RSI@tv-basicstudies',
      label: 'Relative Strength Index',
    ),
    ChartIndicator(
      id: 'rvi',
      study: 'VigorIndex@tv-basicstudies',
      label: 'Relative Vigor Index',
    ),
    ChartIndicator(
      id: 'stoch',
      study: 'Stochastic@tv-basicstudies',
      label: 'Stochastic',
    ),
    ChartIndicator(
      id: 'stochrsi',
      study: 'StochasticRSI@tv-basicstudies',
      label: 'Stochastic RSI',
    ),
    ChartIndicator(
      id: 'tema',
      study: 'TripleEMA@tv-basicstudies',
      label: 'Triple EMA',
    ),
    ChartIndicator(
      id: 'trix',
      study: 'Trix@tv-basicstudies',
      label: 'TRIX',
    ),
    ChartIndicator(
      id: 'uo',
      study: 'UltimateOsc@tv-basicstudies',
      label: 'Ultimate Oscillator',
    ),
    ChartIndicator(
      id: 'vwap',
      study: 'VWAP@tv-basicstudies',
      label: 'VWAP',
    ),
    ChartIndicator(
      id: 'vwma',
      study: 'MAVolumeWeighted@tv-basicstudies',
      label: 'VWMA',
    ),
    ChartIndicator(
      id: 'willr',
      study: 'WilliamR@tv-basicstudies',
      label: 'Williams %R',
    ),
    ChartIndicator(
      id: 'alligator',
      study: 'WilliamsAlligator@tv-basicstudies',
      label: 'Williams Alligator',
    ),
    ChartIndicator(
      id: 'fractal',
      study: 'WilliamsFractal@tv-basicstudies',
      label: 'Williams Fractal',
    ),
    ChartIndicator(
      id: 'zigzag',
      study: 'ZigZag@tv-basicstudies',
      label: 'Zig Zag',
    ),
  ];
}
