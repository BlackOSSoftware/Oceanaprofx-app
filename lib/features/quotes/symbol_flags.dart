import 'package:flutter/material.dart';

import '../../ui/theme/oceana_colors.dart';

/// Overlapping currency / metal badges for watchlist rows (screenshot style).
class SymbolFlagPair extends StatelessWidget {
  const SymbolFlagPair({super.key, required this.symbol, this.size = 36});

  final String symbol;
  final double size;

  static const _ccy = <String, String>{
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
    'JPY': '🇯🇵',
    'AUD': '🇦🇺',
    'CAD': '🇨🇦',
    'CHF': '🇨🇭',
    'NZD': '🇳🇿',
    'CNH': '🇨🇳',
    'CNY': '🇨🇳',
    'HKD': '🇭🇰',
    'SGD': '🇸🇬',
    'SEK': '🇸🇪',
    'NOK': '🇳🇴',
    'DKK': '🇩🇰',
    'ZAR': '🇿🇦',
    'MXN': '🇲🇽',
    'TRY': '🇹🇷',
    'INR': '🇮🇳',
    'RUB': '🇷🇺',
    'XAU': '🥇',
    'XAG': '🥈',
    'GOLD': '🥇',
    'SILVER': '🥈',
    'BTC': '₿',
    'ETH': 'Ξ',
    'BRENT': '🛢',
    'WTI': '🛢',
    'USOIL': '🛢',
    'UKOIL': '🛢',
  };

  static (String, String) parts(String symbol) {
    final s = symbol.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (s.startsWith('XAU') || s == 'GOLD') return ('XAU', 'USD');
    if (s.startsWith('XAG') || s == 'SILVER') return ('XAG', 'USD');
    if (s.startsWith('BTC')) return ('BTC', 'USD');
    if (s.startsWith('ETH')) return ('ETH', 'USD');
    if (s.contains('BRENT') || s.contains('UKOIL')) return ('BRENT', 'USD');
    if (s.contains('WTI') || s.contains('USOIL')) return ('WTI', 'USD');
    if (s.length >= 6) return (s.substring(0, 3), s.substring(3, 6));
    if (s.length >= 3) return (s.substring(0, 3), 'USD');
    return (s, '');
  }

  static String emoji(String code) => _ccy[code.toUpperCase()] ?? '💱';

  @override
  Widget build(BuildContext context) {
    final (a, b) = parts(symbol);
    final badge = size * 0.72;
    if (b.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: _badge(a, badge)),
      );
    }

    // Front flag on right — stack reads right → left.
    return SizedBox(
      width: size + badge * 0.2,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: size - badge,
            child: _badge(a, badge),
          ),
          Positioned(
            left: badge * 0.38,
            top: 0,
            child: _badge(b, badge),
          ),
        ],
      ),
    );
  }

  Widget _badge(String code, double d) {
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: OcColors.primarySoft,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        emoji(code),
        style: TextStyle(fontSize: d * 0.48, height: 1),
      ),
    );
  }
}

/// Squared flag tile for Add-instruments list.
class SymbolFlagTile extends StatelessWidget {
  const SymbolFlagTile({super.key, required this.symbol, this.size = 44});

  final String symbol;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (a, b) = SymbolFlagPair.parts(symbol);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OcColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        b.isEmpty
            ? SymbolFlagPair.emoji(a)
            : '${SymbolFlagPair.emoji(a)}${SymbolFlagPair.emoji(b)}',
        style: TextStyle(fontSize: size * 0.32, height: 1),
        textAlign: TextAlign.center,
      ),
    );
  }
}

String segmentLabel(String segment) {
  return switch (segment.toUpperCase()) {
    'FOREX' || 'CURRENCY' => 'Currency',
    'METAL' || 'METALS' => 'Metals',
    'INDEX' || 'INDICES' || 'INDEXES' => 'Indices',
    'ENERGY' || 'ENERGIES' => 'Energies',
    'CRYPTO' => 'Crypto',
    'COMMODITY' || 'COMMODITIES' => 'Commodities',
    'STOCK' => 'Stocks',
    _ => segment.isEmpty
        ? 'Instrument'
        : segment[0].toUpperCase() + segment.substring(1).toLowerCase(),
  };
}
