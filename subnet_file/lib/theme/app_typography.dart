import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme textTheme({double scale = 1}) {
    double s(double value) => value * scale;
    return TextTheme(
      displayLarge: GoogleFonts.dmSans(
        fontSize: s(34),
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineLarge: GoogleFonts.dmSans(
        fontSize: s(28),
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: s(22),
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: s(18),
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: s(17),
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: s(15),
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: s(15),
        fontWeight: FontWeight.w400,
        height: 1.42,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: s(14),
        fontWeight: FontWeight.w400,
        height: 1.42,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: s(12),
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: s(14),
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: s(12),
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    );
  }
}

