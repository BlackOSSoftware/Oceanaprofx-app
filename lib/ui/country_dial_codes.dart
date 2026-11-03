/// Compact country dial list for phone pickers (flag emoji + ISO + dial).
class CountryDial {
  const CountryDial({
    required this.name,
    required this.iso2,
    required this.dial,
    required this.flag,
  });

  final String name;
  final String iso2;
  final String dial; // e.g. +91
  final String flag;

  String get label => '$flag  $dial';
}

abstract final class CountryDialCodes {
  static const List<CountryDial> all = [
    CountryDial(name: 'India', iso2: 'IN', dial: '+91', flag: '🇮🇳'),
    CountryDial(name: 'United Arab Emirates', iso2: 'AE', dial: '+971', flag: '🇦🇪'),
    CountryDial(name: 'United States', iso2: 'US', dial: '+1', flag: '🇺🇸'),
    CountryDial(name: 'United Kingdom', iso2: 'GB', dial: '+44', flag: '🇬🇧'),
    CountryDial(name: 'Canada', iso2: 'CA', dial: '+1', flag: '🇨🇦'),
    CountryDial(name: 'Australia', iso2: 'AU', dial: '+61', flag: '🇦🇺'),
    CountryDial(name: 'Singapore', iso2: 'SG', dial: '+65', flag: '🇸🇬'),
    CountryDial(name: 'Malaysia', iso2: 'MY', dial: '+60', flag: '🇲🇾'),
    CountryDial(name: 'Indonesia', iso2: 'ID', dial: '+62', flag: '🇮🇩'),
    CountryDial(name: 'Thailand', iso2: 'TH', dial: '+66', flag: '🇹🇭'),
    CountryDial(name: 'Philippines', iso2: 'PH', dial: '+63', flag: '🇵🇭'),
    CountryDial(name: 'Vietnam', iso2: 'VN', dial: '+84', flag: '🇻🇳'),
    CountryDial(name: 'Japan', iso2: 'JP', dial: '+81', flag: '🇯🇵'),
    CountryDial(name: 'South Korea', iso2: 'KR', dial: '+82', flag: '🇰🇷'),
    CountryDial(name: 'China', iso2: 'CN', dial: '+86', flag: '🇨🇳'),
    CountryDial(name: 'Hong Kong', iso2: 'HK', dial: '+852', flag: '🇭🇰'),
    CountryDial(name: 'Pakistan', iso2: 'PK', dial: '+92', flag: '🇵🇰'),
    CountryDial(name: 'Bangladesh', iso2: 'BD', dial: '+880', flag: '🇧🇩'),
    CountryDial(name: 'Sri Lanka', iso2: 'LK', dial: '+94', flag: '🇱🇰'),
    CountryDial(name: 'Nepal', iso2: 'NP', dial: '+977', flag: '🇳🇵'),
    CountryDial(name: 'Saudi Arabia', iso2: 'SA', dial: '+966', flag: '🇸🇦'),
    CountryDial(name: 'Qatar', iso2: 'QA', dial: '+974', flag: '🇶🇦'),
    CountryDial(name: 'Kuwait', iso2: 'KW', dial: '+965', flag: '🇰🇼'),
    CountryDial(name: 'Bahrain', iso2: 'BH', dial: '+973', flag: '🇧🇭'),
    CountryDial(name: 'Oman', iso2: 'OM', dial: '+968', flag: '🇴🇲'),
    CountryDial(name: 'Germany', iso2: 'DE', dial: '+49', flag: '🇩🇪'),
    CountryDial(name: 'France', iso2: 'FR', dial: '+33', flag: '🇫🇷'),
    CountryDial(name: 'Italy', iso2: 'IT', dial: '+39', flag: '🇮🇹'),
    CountryDial(name: 'Spain', iso2: 'ES', dial: '+34', flag: '🇪🇸'),
    CountryDial(name: 'Netherlands', iso2: 'NL', dial: '+31', flag: '🇳🇱'),
    CountryDial(name: 'Switzerland', iso2: 'CH', dial: '+41', flag: '🇨🇭'),
    CountryDial(name: 'Sweden', iso2: 'SE', dial: '+46', flag: '🇸🇪'),
    CountryDial(name: 'Norway', iso2: 'NO', dial: '+47', flag: '🇳🇴'),
    CountryDial(name: 'Denmark', iso2: 'DK', dial: '+45', flag: '🇩🇰'),
    CountryDial(name: 'Poland', iso2: 'PL', dial: '+48', flag: '🇵🇱'),
    CountryDial(name: 'Turkey', iso2: 'TR', dial: '+90', flag: '🇹🇷'),
    CountryDial(name: 'Russia', iso2: 'RU', dial: '+7', flag: '🇷🇺'),
    CountryDial(name: 'South Africa', iso2: 'ZA', dial: '+27', flag: '🇿🇦'),
    CountryDial(name: 'Nigeria', iso2: 'NG', dial: '+234', flag: '🇳🇬'),
    CountryDial(name: 'Kenya', iso2: 'KE', dial: '+254', flag: '🇰🇪'),
    CountryDial(name: 'Egypt', iso2: 'EG', dial: '+20', flag: '🇪🇬'),
    CountryDial(name: 'Brazil', iso2: 'BR', dial: '+55', flag: '🇧🇷'),
    CountryDial(name: 'Mexico', iso2: 'MX', dial: '+52', flag: '🇲🇽'),
    CountryDial(name: 'Argentina', iso2: 'AR', dial: '+54', flag: '🇦🇷'),
    CountryDial(name: 'New Zealand', iso2: 'NZ', dial: '+64', flag: '🇳🇿'),
  ];

  static CountryDial get defaultIndia => all.first;

  /// Match saved phone like `+919876543210` → (country, national).
  static (CountryDial, String) splitPhone(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (cleaned.isEmpty) return (defaultIndia, '');

    var digits = cleaned;
    if (!digits.startsWith('+') && digits.startsWith('00')) {
      digits = '+${digits.substring(2)}';
    }

    if (digits.startsWith('+')) {
      final sorted = [...all]
        ..sort((a, b) => b.dial.length.compareTo(a.dial.length));
      for (final c in sorted) {
        if (digits.startsWith(c.dial)) {
          return (c, digits.substring(c.dial.length));
        }
      }
      // Unknown +code — keep full string in national, default dial India.
      return (defaultIndia, digits.replaceFirst('+', ''));
    }

    // Bare number — assume India if 10 digits.
    if (RegExp(r'^\d{10}$').hasMatch(digits)) {
      return (defaultIndia, digits);
    }
    return (defaultIndia, digits);
  }

  static List<CountryDial> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return all;
    return all
        .where(
          (c) =>
              c.name.toLowerCase().contains(s) ||
              c.dial.contains(s) ||
              c.iso2.toLowerCase().contains(s),
        )
        .toList();
  }
}
