import 'package:flutter/material.dart';

import 'design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final scheme = const ColorScheme.dark().copyWith(
      primary: GameColors.accent,
      onPrimary: GameColors.backgroundDeep,
      secondary: GameColors.violet,
      onSecondary: GameColors.textStrong,
      surface: GameColors.surface,
      onSurface: GameColors.textStrong,
      error: GameColors.danger,
      onError: GameColors.textStrong,
      outline: GameColors.surfaceStrong,
      outlineVariant: GameColors.surfaceRaised,
    );

    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: GameColors.textStrong,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: GameColors.textStrong,
        fontWeight: FontWeight.w900,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: GameColors.textStrong,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: GameColors.textStrong,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: GameColors.textStrong,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: GameColors.textStrong),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: GameColors.textSoft),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: GameColors.muted),
      labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: GameColors.background,
      dividerColor: GameColors.surfaceStrong,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: GameColors.textStrong,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: GameColors.accent,
          foregroundColor: GameColors.backgroundDeep,
          disabledBackgroundColor: GameColors.surfaceRaised,
          disabledForegroundColor: GameColors.muted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameRadii.button),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: GameColors.textStrong,
          side: const BorderSide(color: GameColors.surfaceStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameRadii.button),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GameColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        color: GameColors.surfaceGlass,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: GameColors.surfaceStrong, width: 0.8),
          borderRadius: BorderRadius.circular(GameRadii.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GameColors.surfaceGlass,
        labelStyle: const TextStyle(color: GameColors.muted),
        helperStyle: const TextStyle(color: GameColors.muted),
        hintStyle: const TextStyle(color: GameColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GameRadii.button),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GameRadii.button),
          borderSide: const BorderSide(color: GameColors.surfaceStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GameRadii.button),
          borderSide: const BorderSide(color: GameColors.accent, width: 1.4),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GameColors.accent,
        linearTrackColor: GameColors.surfaceRaised,
        circularTrackColor: GameColors.surfaceRaised,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: GameColors.surfaceRaised,
        selectedColor: GameColors.accentSoft,
        side: const BorderSide(color: GameColors.surfaceStrong),
        labelStyle: const TextStyle(color: GameColors.textSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameRadii.pill),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: GameColors.surfaceGlass,
        indicatorColor: GameColors.accentSoft,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GameColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: GameColors.surfaceStrong),
          borderRadius: BorderRadius.circular(GameRadii.panel),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GameColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: GameColors.surface,
        showDragHandle: true,
      ),
    );
  }
}
