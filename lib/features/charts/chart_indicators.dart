/// Built-in indicators for TradingView Lightweight Charts (broker OHLC).
///
/// Catalog = addable types. Active chart uses [ChartIndicatorConfig] instances
/// so multiple MAs (different length/colour) can run together.
class ChartIndicator {
  const ChartIndicator({
    required this.type,
    required this.label,
    this.subtitle = '',
    this.allowMultiple = false,
  });

  /// Engine type key: sma, ema, bb, rsi, …
  final String type;
  final String label;
  final String subtitle;

  /// MA / EMA can be added many times with different settings.
  final bool allowMultiple;

  /// Kept for older call sites that used `id` / `study`.
  String get id => type;
  String get study => type.toUpperCase();

  static const palette = <String>[
    '#F5A623',
    '#3498DB',
    '#9B59B6',
    '#E67E22',
    '#1ABC9C',
    '#E91E63',
    '#00BCD4',
    '#8BC34A',
    '#FF5722',
    '#607D8B',
  ];

  static const catalog = <ChartIndicator>[
    ChartIndicator(
      type: 'vol',
      label: 'Volume',
      subtitle: 'Histogram',
    ),
    ChartIndicator(
      type: 'sma',
      label: 'Moving Average',
      subtitle: 'SMA — add multiple',
      allowMultiple: true,
    ),
    ChartIndicator(
      type: 'ema',
      label: 'Moving Average Exponential',
      subtitle: 'EMA — add multiple',
      allowMultiple: true,
    ),
    ChartIndicator(
      type: 'bb',
      label: 'Bollinger Bands',
      subtitle: 'Length · StdDev',
    ),
    ChartIndicator(
      type: 'rsi',
      label: 'Relative Strength Index',
      subtitle: 'Length',
    ),
    ChartIndicator(
      type: 'macd',
      label: 'MACD',
      subtitle: 'Fast · Slow · Signal',
    ),
    ChartIndicator(
      type: 'stoch',
      label: 'Stochastic',
      subtitle: '%K · %D',
    ),
    ChartIndicator(
      type: 'atr',
      label: 'Average True Range',
      subtitle: 'Length',
    ),
    ChartIndicator(
      type: 'mom',
      label: 'Momentum',
      subtitle: 'Length',
    ),
    ChartIndicator(
      type: 'cci',
      label: 'Commodity Channel Index',
      subtitle: 'Length',
    ),
    ChartIndicator(
      type: 'willr',
      label: 'Williams %R',
      subtitle: 'Length',
    ),
    ChartIndicator(
      type: 'ao',
      label: 'Awesome Oscillator',
      subtitle: 'SMA 5 − SMA 34',
    ),
  ];

  static ChartIndicator? byType(String type) {
    for (final i in catalog) {
      if (i.type == type) return i;
    }
    return null;
  }

  static String nextColor(List<ChartIndicatorConfig> existing, String type) {
    final used = {
      for (final c in existing)
        if (c.type == type) c.color.toUpperCase(),
    };
    for (final p in palette) {
      if (!used.contains(p.toUpperCase())) return p;
    }
    return palette[existing.length % palette.length];
  }
}

/// One live indicator instance on the chart (with editable settings).
class ChartIndicatorConfig {
  ChartIndicatorConfig({
    required this.instanceId,
    required this.type,
    this.length = 20,
    this.length2 = 26,
    this.length3 = 9,
    this.mult = 2.0,
    this.color = '#F5A623',
    this.color2 = '#2196F3',
    this.color3 = '#FF9800',
  });

  final String instanceId;
  final String type;
  int length;
  int length2;
  int length3;
  double mult;
  String color;
  String color2;
  String color3;

  String get label {
    final base = ChartIndicator.byType(type)?.label ?? type.toUpperCase();
    return switch (type) {
      'sma' => 'SMA $length',
      'ema' => 'EMA $length',
      'bb' => 'BB $length ($mult)',
      'rsi' => 'RSI $length',
      'macd' => 'MACD $length · $length2 · $length3',
      'stoch' => 'Stoch $length · $length3',
      'atr' => 'ATR $length',
      'mom' => 'Mom $length',
      'cci' => 'CCI $length',
      'willr' => 'Will%R $length',
      'vol' => 'Volume',
      'ao' => 'AO',
      _ => base,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': instanceId,
        'type': type,
        'length': length,
        'length2': length2,
        'length3': length3,
        'mult': mult,
        'color': color,
        'color2': color2,
        'color3': color3,
      };

  ChartIndicatorConfig copy() => ChartIndicatorConfig(
        instanceId: instanceId,
        type: type,
        length: length,
        length2: length2,
        length3: length3,
        mult: mult,
        color: color,
        color2: color2,
        color3: color3,
      );

  static ChartIndicatorConfig create(
    ChartIndicator kind, {
    required List<ChartIndicatorConfig> existing,
  }) {
    final id =
        '${kind.type}_${DateTime.now().microsecondsSinceEpoch}_${existing.length}';
    final color = ChartIndicator.nextColor(existing, kind.type);
    return switch (kind.type) {
      'sma' => ChartIndicatorConfig(
          instanceId: id,
          type: 'sma',
          length: 20,
          color: color,
        ),
      'ema' => ChartIndicatorConfig(
          instanceId: id,
          type: 'ema',
          length: 20,
          color: color,
        ),
      'bb' => ChartIndicatorConfig(
          instanceId: id,
          type: 'bb',
          length: 20,
          mult: 2,
          color: '#787B86',
          color2: '#2196F3',
        ),
      'rsi' => ChartIndicatorConfig(
          instanceId: id,
          type: 'rsi',
          length: 14,
          color: '#7B1FA2',
        ),
      'macd' => ChartIndicatorConfig(
          instanceId: id,
          type: 'macd',
          length: 12,
          length2: 26,
          length3: 9,
          color: '#2196F3',
          color2: '#FF9800',
        ),
      'stoch' => ChartIndicatorConfig(
          instanceId: id,
          type: 'stoch',
          length: 14,
          length3: 3,
          color: '#2196F3',
          color2: '#FF9800',
        ),
      'atr' => ChartIndicatorConfig(
          instanceId: id,
          type: 'atr',
          length: 14,
          color: '#26A69A',
        ),
      'mom' => ChartIndicatorConfig(
          instanceId: id,
          type: 'mom',
          length: 10,
          color: '#E91E63',
        ),
      'cci' => ChartIndicatorConfig(
          instanceId: id,
          type: 'cci',
          length: 20,
          color: '#00BCD4',
        ),
      'willr' => ChartIndicatorConfig(
          instanceId: id,
          type: 'willr',
          length: 14,
          color: '#8BC34A',
        ),
      'vol' => ChartIndicatorConfig(
          instanceId: id,
          type: 'vol',
          color: '#26A69A',
        ),
      'ao' => ChartIndicatorConfig(
          instanceId: id,
          type: 'ao',
          length: 5,
          length2: 34,
          color: '#26A69A',
        ),
      _ => ChartIndicatorConfig(instanceId: id, type: kind.type, color: color),
    };
  }
}
