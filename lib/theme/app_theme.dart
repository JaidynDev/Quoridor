import 'package:flutter/material.dart';

/// Palette pulled from the 3D board so the menus and the table match.
class AppPalette {
  static const Color pine = Color(0xFF16705B);
  static const Color pineDark = Color(0xFF0E4F40);
  static const Color slate = Color(0xFF25404F);
  static const Color slateDeep = Color(0xFF162B36);
  static const Color wood = Color(0xFFA9682B);
  static const Color parchment = Color(0xFFF4EADB);
  static const Color surface = Color(0xFFFFFCF6);
  static const Color ink = Color(0xFF23201B);
  static const Color inkSoft = Color(0xFF6B6459);
  static const Color hairline = Color(0xFFE3D7C4);
}

class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.pine,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCDE9DF),
      onPrimaryContainer: AppPalette.pineDark,
      secondary: AppPalette.wood,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF6E3C9),
      onSecondaryContainer: Color(0xFF5C3A12),
      tertiary: AppPalette.slate,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD5E3EA),
      onTertiaryContainer: AppPalette.slateDeep,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      surfaceContainerHighest: Color(0xFFF0E6D6),
      onSurfaceVariant: AppPalette.inkSoft,
      outline: Color(0xFFCFC2AC),
      outlineVariant: AppPalette.hairline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.parchment,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: AppPalette.ink, displayColor: AppPalette.ink)
          .copyWith(
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            labelLarge: base.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppPalette.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppPalette.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.ink,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: AppPalette.hairline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F0E4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.pine, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: AppPalette.inkSoft,
        indicatorColor: scheme.primary,
        dividerColor: AppPalette.hairline,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.slateDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: AppPalette.hairline, space: 1),
      listTileTheme: const ListTileThemeData(iconColor: AppPalette.inkSoft),
    );
  }
}
