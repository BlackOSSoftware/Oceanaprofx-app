import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'oceana_colors.dart';

class OceanaScrollBehavior extends MaterialScrollBehavior {
  const OceanaScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}

abstract final class OceanaTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  /// Build ThemeData for [brightness] without mutating [OcColors].
  /// Palette mutation happens only via [setMtDarkMode] so light/dark
  /// MaterialApp theme getters don't fight each other.
  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;

    // Local tokens — portal light/dark design system (`#0042FC`).
    final primary = OcColors.brand;
    final bg = dark ? const Color(0xFF0E0E10) : const Color(0xFFF4F4F7);
    final surface = dark ? const Color(0xFF19191F) : const Color(0xFFFFFFFF);
    final border = dark ? const Color(0xFF30303A) : const Color(0xFFE4E4E9);
    final borderStrong =
        dark ? const Color(0xFF373744) : const Color(0xFFDADAE3);
    final text = dark ? const Color(0xFFF7F7FA) : const Color(0xFF111116);
    final textSecondary =
        dark ? const Color(0xFFA6A6B2) : const Color(0xFF686875);
    final placeholder =
        dark ? const Color(0xFF777783) : const Color(0xFF9696A2);
    final primaryMuted =
        dark ? const Color(0xFF16246E) : const Color(0xFFDBE7FF);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: primary,
      canvasColor: bg,
      cardColor: surface,
      dividerColor: border,
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: OcColors.onPrimary,
        secondary: primaryMuted,
        onSecondary: OcColors.onPrimary,
        error: OcColors.danger,
        onError: OcColors.onPrimary,
        surface: surface,
        onSurface: text,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: bg,
        foregroundColor: text,
        iconTheme: IconThemeData(color: text),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: bg,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.black,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: OcColors.onPrimary,
          disabledBackgroundColor: primary.withValues(alpha: 0.45),
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: borderStrong, width: 1),
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: GoogleFonts.inter(color: placeholder, fontSize: 13.5),
        labelStyle: GoogleFonts.inter(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            dark ? const Color(0xFF2A2A30) : const Color(0xFF323232),
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return primary;
          return dark ? const Color(0xFF373744) : const Color(0xFFDADAE3);
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: text,
      ),
      iconTheme: IconThemeData(color: text),
      dividerTheme: DividerThemeData(color: border, thickness: 0.7),
    );

    final inter = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: text,
      displayColor: text,
    );
    return base.copyWith(
      textTheme: _scaleTextTheme(inter, 0.94),
      primaryTextTheme: _scaleTextTheme(inter, 0.94),
    );
  }

  static TextTheme _scaleTextTheme(TextTheme theme, double factor) {
    TextStyle? scale(TextStyle? s) {
      if (s == null) return null;
      final size = s.fontSize;
      if (size == null) return s;
      return s.copyWith(fontSize: size * factor);
    }

    return theme.copyWith(
      displayLarge: scale(theme.displayLarge),
      displayMedium: scale(theme.displayMedium),
      displaySmall: scale(theme.displaySmall),
      headlineLarge: scale(theme.headlineLarge),
      headlineMedium: scale(theme.headlineMedium),
      headlineSmall: scale(theme.headlineSmall),
      titleLarge: scale(theme.titleLarge),
      titleMedium: scale(theme.titleMedium),
      titleSmall: scale(theme.titleSmall),
      bodyLarge: scale(theme.bodyLarge),
      bodyMedium: scale(theme.bodyMedium),
      bodySmall: scale(theme.bodySmall),
      labelLarge: scale(theme.labelLarge),
      labelMedium: scale(theme.labelMedium),
      labelSmall: scale(theme.labelSmall),
    );
  }
}
