import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData dark({
    Color primaryAccent = AppColors.primary,
    double fontScale = 1,
  }) {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
    );

    final textTheme = AppTypography.textTheme(scale: fontScale);

    return base.copyWith(
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: AppColors.appBg,
      primaryColor: primaryAccent,
      cardColor: AppColors.surfaceCard,
      dividerColor: AppColors.borderSubtle,
      colorScheme: ColorScheme.dark(
        primary: primaryAccent,
        secondary: AppColors.ghost,
        surface: AppColors.surfaceBase,
        error: AppColors.danger,
      ),
      textTheme: textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceBase,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 22),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.95),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceCard,
        border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.borderGlow, width: 1),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primaryGlow,
        selectionHandleColor: AppColors.primary,
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.transparent,
        indicatorColor: primaryAccent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? primaryAccent : AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(color: active ? primaryAccent : AppColors.textTertiary, size: 24);
        }),
      ),
    );
  }
}

