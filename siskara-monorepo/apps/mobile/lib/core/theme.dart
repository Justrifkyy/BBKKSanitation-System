import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ARJUNA design system — colors, typography, and theme data.
typedef ArjunaTheme = SiskaraTheme;

class SiskaraTheme {
  SiskaraTheme._();

  // ─── Brand Colors ───────────────────────────────────────
  static const Color primaryBlue = Color(0xFF176B66);
  static const Color primaryDark = Color(0xFF0B3F48);
  static const Color primaryLight = Color(0xFF63B6A9);
  static const Color accentTeal = Color(0xFF2D8C78);
  static const Color accentGold = Color(0xFFD69B35);

  // ─── Semantic Colors ────────────────────────────────────
  static const Color success = Color(0xFF25734D);
  static const Color warning = Color(0xFF9A6400);
  static const Color error = Color(0xFFB93838);
  static const Color info = Color(0xFF176B66);

  // ─── Status Colors (submission flow) ────────────────────
  static const Color statusDraft = Color(0xFF78909C);
  static const Color statusAutoReject = Color(0xFFD32F2F);
  static const Color statusPending = Color(0xFFF9A825);
  static const Color statusRejected = Color(0xFFE53935);
  static const Color statusFinal = Color(0xFF2E7D32);

  // ─── Neutrals ───────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF3F7F6);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF172B36);
  static const Color textSecondary = Color(0xFF52666D);
  static const Color divider = Color(0xFFDCE6E4);

  // Dark mode
  static const Color backgroundDark = Color(0xFF101B1C);
  static const Color surfaceDark = Color(0xFF192729);
  static const Color textPrimaryDark = Color(0xFFE0E0E0);
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // ─── Spacing ────────────────────────────────────────────
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 48;

  // ─── Border Radius ─────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;

  // ─── Standardized Typography Scale ───────────────────────
  // 1. Judul (Headings & Titles)
  static TextStyle get titleScreen => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get titleSection => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle get titleCard => GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  // 2. Penjelasan & Teks Konten (Body, Subtitle, Meta)
  static TextStyle get bodyPrimary => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
        height: 1.45,
      );

  static TextStyle get bodySecondary => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
        height: 1.4,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  static TextStyle get badgeLabel => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  // 3. Inputan Form
  static TextStyle get inputLabel => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      );

  static TextStyle get inputText => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );

  static TextStyle get inputHint => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      );

  // ─── Light Theme ────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        primary: primaryBlue,
        secondary: accentTeal,
        tertiary: accentGold,
        error: error,
        surface: surfaceLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 54,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceLight,
        height: 64,
        indicatorColor: primaryBlue.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          minimumSize: const Size(0, 44),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(color: primaryBlue),
          textStyle: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: textSecondary),
        hintStyle: GoogleFonts.inter(fontSize: 13, color: textSecondary.withValues(alpha: 0.7)),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: divider, width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }

  // ─── Dark Theme ─────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        primary: primaryLight,
        secondary: accentTeal,
        tertiary: accentGold,
        error: error,
        surface: surfaceDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textPrimaryDark,
        displayColor: textPrimaryDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 54,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryDark,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceDark,
        height: 64,
        indicatorColor: primaryLight.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: textPrimaryDark,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: backgroundDark,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondaryDark),
        hintStyle: GoogleFonts.inter(color: textSecondaryDark),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
    );
  }

  // ─── Utility: Status Color Mapper ───────────────────────
  static Color statusColor(String status) {
    switch (status) {
      case 'draft':
        return statusDraft;
      case 'ditolak_otomatis':
        return statusAutoReject;
      case 'menunggu_verifikasi_staf':
        return statusPending;
      case 'ditolak_staf':
        return statusRejected;
      case 'final':
        return statusFinal;
      default:
        return statusDraft;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'ditolak_otomatis':
        return 'Ditolak Otomatis';
      case 'menunggu_verifikasi_staf':
        return 'Menunggu Verifikasi';
      case 'ditolak_staf':
        return 'Ditolak Staf';
      case 'final':
        return 'Final';
      default:
        return status;
    }
  }
}
