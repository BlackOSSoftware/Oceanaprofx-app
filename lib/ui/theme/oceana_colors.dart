import 'package:flutter/material.dart';

/// Client UI palette — brand blue `#1414C7` (light).
/// Dark mode uses a brighter accent so icons/links stay readable.
/// Call [applyDark] when theme toggles so screens using these colors update.
abstract final class OcColors {
  static bool isDark = false;

  /// Brand blue (light). Dark UI uses a lifted accent for contrast.
  static const Color brand = Color(0xFF1414C7);

  static Color primary = brand;
  static Color primaryDark = const Color(0xFF0F0F9A);
  static Color primarySoft = const Color(0xFFE8E8FA);
  static Color primaryMuted = const Color(0xFFD0D0F5);

  static Color bg = const Color(0xFFF5F5F7);
  static Color surface = const Color(0xFFFFFFFF);
  static Color border = const Color(0xFFE6E6EA);
  static Color borderStrong = const Color(0xFFD0D0D6);

  static Color text = const Color(0xFF111111);
  static Color textSecondary = const Color(0xFF6B6B76);
  static Color textMuted = const Color(0xFF9A9AA3);
  static Color placeholder = const Color(0xFFB0B0B8);

  /// Bid / sell — darker orange-red; ask — darker green.
  static const Color bid = Color(0xFFD1432A);
  static const Color ask = Color(0xFF1F7A38);
  static const Color profit = Color(0xFF1B8A3E);
  static const Color loss = Color(0xFFC62828);

  static Color depositBg = const Color(0xFFA5D6A7);
  static Color depositFg = const Color(0xFF1B5E20);
  static Color withdrawBg = const Color(0xFFEF9A9A);
  static Color withdrawFg = const Color(0xFFC62828);
  static Color transferBg = const Color(0xFFE8E8FA);
  static Color transferFg = brand;
  static Color historyBg = const Color(0xFFE8E8FA);

  /// Orange quick-action / warning chips (adapts in dark).
  /// Also used for More → Withdraw tile.
  static Color orangeBg = const Color(0xFFFFE0B2);
  static Color orangeFg = const Color(0xFFBF360C);
  static Color warnBg = const Color(0xFFFFF3CD);
  static Color warnFg = const Color(0xFFB78103);

  static Color demoBadge = brand;
  static Color liveBadge = brand;
  static const Color danger = Color(0xFFD32F2F);
  static const Color gold = Color(0xFFFFC107);

  static Color navInactive = const Color(0xFF8A8A93);
  static Color navActiveBg = const Color(0xFFE8E8FA);

  /// On-primary / chip text that stays light on brand / accent fills.
  static const Color onPrimary = Color(0xFFFFFFFF);

  static void applyDark(bool dark) {
    isDark = dark;
    if (dark) {
      // Lifted periwinkle — readable on near-black, still “Oceana blue”.
      primary = const Color(0xFF8B9BFF);
      primaryDark = const Color(0xFF6E7EF0);
      primarySoft = const Color(0xFF222838);
      primaryMuted = const Color(0xFF3A4568);
      bg = const Color(0xFF0E0E10);
      surface = const Color(0xFF1A1A1E);
      border = const Color(0xFF33333C);
      borderStrong = const Color(0xFF484852);
      text = const Color(0xFFF4F4F7);
      textSecondary = const Color(0xFFB4B4BE);
      textMuted = const Color(0xFF8E8E98);
      placeholder = const Color(0xFF7A7A85);
      depositBg = const Color(0xFF14301A);
      depositFg = const Color(0xFF81C784);
      withdrawBg = const Color(0xFF321418);
      withdrawFg = const Color(0xFFEF9A9A);
      transferBg = const Color(0xFF222838);
      transferFg = const Color(0xFF8B9BFF);
      historyBg = const Color(0xFF222838);
      orangeBg = const Color(0xFF2A1C10);
      orangeFg = const Color(0xFFFF8A50);
      warnBg = const Color(0xFF3A3018);
      warnFg = const Color(0xFFE6C35C);
      demoBadge = const Color(0xFF8B9BFF);
      liveBadge = const Color(0xFF8B9BFF);
      navInactive = const Color(0xFF9898A2);
      navActiveBg = const Color(0xFF222838);
    } else {
      primary = brand;
      primaryDark = const Color(0xFF0F0F9A);
      primarySoft = const Color(0xFFE8E8FA);
      primaryMuted = const Color(0xFFD0D0F5);
      bg = const Color(0xFFF5F5F7);
      surface = const Color(0xFFFFFFFF);
      border = const Color(0xFFE6E6EA);
      borderStrong = const Color(0xFFD0D0D6);
      text = const Color(0xFF111111);
      textSecondary = const Color(0xFF6B6B76);
      textMuted = const Color(0xFF9A9AA3);
      placeholder = const Color(0xFFB0B0B8);
      depositBg = const Color(0xFFA5D6A7);
      depositFg = const Color(0xFF1B5E20);
      withdrawBg = const Color(0xFFEF9A9A);
      withdrawFg = const Color(0xFFC62828);
      transferBg = const Color(0xFFE8E8FA);
      transferFg = brand;
      historyBg = const Color(0xFFE8E8FA);
      orangeBg = const Color(0xFFFFE0B2);
      orangeFg = const Color(0xFFBF360C);
      warnBg = const Color(0xFFFFF3CD);
      warnFg = const Color(0xFFB78103);
      demoBadge = brand;
      liveBadge = brand;
      navInactive = const Color(0xFF8A8A93);
      navActiveBg = const Color(0xFFE8E8FA);
    }
  }
}
