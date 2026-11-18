import 'package:flutter/material.dart';

/// Client UI palette — matches portal light/dark design system.
/// Brand: Oceanaprofx Blue `#0042FC`.
/// Call [applyDark] when theme toggles so screens using these colors update.
abstract final class OcColors {
  static bool isDark = false;

  /// Brand blue — portal `--primary` / `--brand`.
  static const Color brand = Color(0xFF0042FC);

  static Color primary = brand;
  static Color primaryDark = const Color(0xFF0033CC);
  static Color primarySoft = const Color(0xFFE8EFFF);
  static Color primaryMuted = const Color(0xFFDBE7FF);

  static Color bg = const Color(0xFFF4F4F7);
  static Color surface = const Color(0xFFFFFFFF);
  static Color border = const Color(0xFFE4E4E9);
  static Color borderStrong = const Color(0xFFDADAE3);

  static Color text = const Color(0xFF111116);
  static Color textSecondary = const Color(0xFF686875);
  static Color textMuted = const Color(0xFF9696A2);
  static Color placeholder = const Color(0xFF9696A2);

  /// Bid / sell — darker orange-red; ask — darker green.
  static const Color bid = Color(0xFFD1432A);
  static const Color ask = Color(0xFF1F7A38);
  static const Color profit = Color(0xFF1B8A3E);
  static const Color loss = Color(0xFFC62828);

  static Color depositBg = const Color(0xFFE8F5E9);
  static Color depositFg = const Color(0xFF2E7D32);
  static Color withdrawBg = const Color(0xFFFFF3E0);
  static Color withdrawFg = const Color(0xFFE65100);
  static Color transferBg = const Color(0xFFECECF8);
  static Color transferFg = brand;
  static Color historyBg = const Color(0xFFE8EFFF);

  /// Orange quick-action / warning chips (adapts in dark).
  /// Also used for More → Withdraw tile.
  static Color orangeBg = const Color(0xFFFFF3E0);
  static Color orangeFg = const Color(0xFFE65100);
  static Color warnBg = const Color(0xFFFFF3CD);
  static Color warnFg = const Color(0xFFB78103);

  static Color demoBadge = brand;
  static Color liveBadge = brand;
  static const Color danger = Color(0xFFD32F2F);
  static const Color gold = Color(0xFFFFC107);

  static Color navInactive = const Color(0xFF9696A2);
  static Color navActiveBg = const Color(0xFFE8EFFF);

  /// On-primary / chip text that stays light on brand / accent fills.
  static const Color onPrimary = Color(0xFFFFFFFF);

  static void applyDark(bool dark) {
    isDark = dark;
    if (dark) {
      // Portal `.dark` tokens — brand stays cobalt; soft accents use periwinkle.
      primary = brand;
      primaryDark = const Color(0xFF2F66FF);
      primarySoft = const Color(0xFF222638);
      primaryMuted = const Color(0xFF16246E);
      bg = const Color(0xFF0E0E10);
      surface = const Color(0xFF19191F);
      border = const Color(0xFF30303A);
      borderStrong = const Color(0xFF373744);
      text = const Color(0xFFF7F7FA);
      textSecondary = const Color(0xFFA6A6B2);
      textMuted = const Color(0xFF777783);
      placeholder = const Color(0xFF777783);
      depositBg = const Color(0xFF16301C);
      depositFg = const Color(0xFF66BB6A);
      withdrawBg = const Color(0xFF3A2818);
      withdrawFg = const Color(0xFFFF8A50);
      transferBg = const Color(0xFF222638);
      transferFg = const Color(0xFF7AA8FF);
      historyBg = const Color(0xFF222638);
      orangeBg = const Color(0xFF3A2818);
      orangeFg = const Color(0xFFFF8A50);
      warnBg = const Color(0xFF3A3018);
      warnFg = const Color(0xFFD4A017);
      demoBadge = const Color(0xFF7AA8FF);
      liveBadge = const Color(0xFF7AA8FF);
      navInactive = const Color(0xFF777783);
      navActiveBg = const Color(0xFF252A3B);
    } else {
      primary = brand;
      primaryDark = const Color(0xFF0033CC);
      primarySoft = const Color(0xFFE8EFFF);
      primaryMuted = const Color(0xFFDBE7FF);
      bg = const Color(0xFFF4F4F7);
      surface = const Color(0xFFFFFFFF);
      border = const Color(0xFFE4E4E9);
      borderStrong = const Color(0xFFDADAE3);
      text = const Color(0xFF111116);
      textSecondary = const Color(0xFF686875);
      textMuted = const Color(0xFF9696A2);
      placeholder = const Color(0xFF9696A2);
      depositBg = const Color(0xFFE8F5E9);
      depositFg = const Color(0xFF2E7D32);
      withdrawBg = const Color(0xFFFFF3E0);
      withdrawFg = const Color(0xFFE65100);
      transferBg = const Color(0xFFECECF8);
      transferFg = brand;
      historyBg = const Color(0xFFE8EFFF);
      orangeBg = const Color(0xFFFFF3E0);
      orangeFg = const Color(0xFFE65100);
      warnBg = const Color(0xFFFFF3CD);
      warnFg = const Color(0xFFB78103);
      demoBadge = brand;
      liveBadge = brand;
      navInactive = const Color(0xFF9696A2);
      navActiveBg = const Color(0xFFE8EFFF);
    }
  }
}
