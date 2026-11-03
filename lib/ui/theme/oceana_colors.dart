import 'package:flutter/material.dart';

/// Client UI palette — brand blue `#1414C7`.
/// Call [applyDark] when theme toggles so screens using these colors update.
abstract final class OcColors {
  static bool isDark = false;

  static const Color primary = Color(0xFF1414C7);
  static const Color primaryDark = Color(0xFF0F0F9A);
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

  static Color depositBg = const Color(0xFFE8F5E9);
  static Color depositFg = const Color(0xFF2E7D32);
  static Color withdrawBg = const Color(0xFFFFEBEE);
  static Color withdrawFg = const Color(0xFFC62828);
  static Color transferBg = const Color(0xFFE8E8FA);
  static Color transferFg = const Color(0xFF1414C7);
  static Color historyBg = const Color(0xFFE8E8FA);

  static const Color demoBadge = Color(0xFF1414C7);
  static const Color liveBadge = Color(0xFF1414C7);
  static const Color danger = Color(0xFFD32F2F);
  static const Color gold = Color(0xFFFFC107);

  static Color navInactive = const Color(0xFF8A8A93);
  static Color navActiveBg = const Color(0xFFE8E8FA);

  /// On-primary / chip text that stays light on brand blue.
  static const Color onPrimary = Color(0xFFFFFFFF);

  static void applyDark(bool dark) {
    isDark = dark;
    if (dark) {
      primarySoft = const Color(0xFF1E1E4A);
      primaryMuted = const Color(0xFF3D3DB0);
      bg = const Color(0xFF0E0E10);
      surface = const Color(0xFF1A1A1E);
      border = const Color(0xFF2A2A30);
      borderStrong = const Color(0xFF3A3A42);
      text = const Color(0xFFF2F2F5);
      textSecondary = const Color(0xFFA0A0AB);
      textMuted = const Color(0xFF7A7A85);
      placeholder = const Color(0xFF6A6A75);
      depositBg = const Color(0xFF14301A);
      depositFg = const Color(0xFF81C784);
      withdrawBg = const Color(0xFF3A1518);
      withdrawFg = const Color(0xFFEF9A9A);
      transferBg = const Color(0xFF1E1E4A);
      transferFg = const Color(0xFF9FA8FF);
      historyBg = const Color(0xFF1E1E4A);
      navInactive = const Color(0xFF8A8A93);
      navActiveBg = const Color(0xFF1E1E4A);
    } else {
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
      depositBg = const Color(0xFFE8F5E9);
      depositFg = const Color(0xFF2E7D32);
      withdrawBg = const Color(0xFFFFEBEE);
      withdrawFg = const Color(0xFFC62828);
      transferBg = const Color(0xFFE8E8FA);
      transferFg = const Color(0xFF1414C7);
      historyBg = const Color(0xFFE8E8FA);
      navInactive = const Color(0xFF8A8A93);
      navActiveBg = const Color(0xFFE8E8FA);
    }
  }
}
