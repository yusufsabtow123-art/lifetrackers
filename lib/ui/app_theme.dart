import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF102A4C);
  static const navyMuted = Color(0xFF53677F);
  static const green = Color(0xFF0E9363);
  static const greenDark = Color(0xFF08734D);
  static const warmWhite = Color(0xFFFBFAF7);
  static const panel = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E1DA);
  static const softBlue = Color(0xFFEAF2FF);
  static const softGreen = Color(0xFFE8F5ED);
  static const softAmber = Color(0xFFFFF1DE);
  static const softRed = Color(0xFFFFEAE7);
  // The dark palette mirrors the quiet charcoal hierarchy of the approved
  // Windows design. Surfaces are separated mostly by tone; borders stay soft.
  static const darkBackground = Color(0xFF18191D);
  static const darkPanel = Color(0xFF1F2025);
  static const darkRaised = Color(0xFF27282E);
  static const darkBorder = Color(0xFF34353C);
  static const darkText = Color(0xFFE3E4E9);
  static const darkMuted = Color(0xFF9698A3);
  static const darkSoftGreen = Color(0xFF1D342B);
  static const darkSoftBlue = Color(0xFF27243A);
  static const purple = Color(0xFF7774CD);
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

Color _bestForeground(Color background) {
  final whiteContrast = _contrastRatio(Colors.white, background);
  final blackContrast = _contrastRatio(Colors.black, background);
  return whiteContrast >= blackContrast ? Colors.white : Colors.black;
}

Color _complementaryColor(Color accent) {
  final hsl = HSLColor.fromColor(accent);
  return hsl
      .withHue((hsl.hue + 180) % 360)
      .withSaturation(hsl.saturation.clamp(.35, .68))
      .withLightness(hsl.lightness.clamp(.38, .56))
      .toColor();
}

Color _accessibleAccentText(Color accent, Color background) {
  if (_contrastRatio(accent, background) >= 4.5) return accent;
  final target = background.computeLuminance() > 0.5
      ? Colors.black
      : Colors.white;
  for (var step = 1; step <= 20; step++) {
    final candidate = Color.lerp(accent, target, step / 20)!;
    if (_contrastRatio(candidate, background) >= 4.5) return candidate;
  }
  return target;
}

ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  Color accentColor = AppColors.green,
}) {
  final complementary = _complementaryColor(accentColor);
  final effectiveAccent = brightness == Brightness.dark
      ? Color.lerp(accentColor, AppColors.purple, .68)!
      : accentColor;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: effectiveAccent,
        brightness: brightness,
        surface: brightness == Brightness.dark
            ? AppColors.darkPanel
            : AppColors.warmWhite,
      ).copyWith(
        primary: effectiveAccent,
        onPrimary: _bestForeground(effectiveAccent),
        secondary: complementary,
        onSurface: brightness == Brightness.dark
            ? AppColors.darkText
            : AppColors.navy,
        outline: brightness == Brightness.dark
            ? AppColors.darkBorder
            : AppColors.border,
        error: const Color(0xFFC73B2E),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? AppColors.darkBackground
        : AppColors.warmWhite,
    fontFamily: 'Segoe UI',
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: TextStyle(
        color: scheme.onSurface,
        fontSize: 28,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        color: scheme.onSurface,
        fontSize: 24,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: scheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: scheme.onSurface, height: 1.45),
      bodyMedium: TextStyle(color: scheme.onSurface, height: 1.4),
      bodySmall: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(7)),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(7)),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        foregroundColor: scheme.onSurface,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.warmWhite,
      surfaceTintColor: Colors.transparent,
      shape: Border(
        bottom: BorderSide(
          color: brightness == Brightness.dark
              ? AppColors.darkBorder.withValues(alpha: .72)
              : AppColors.border,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      elevation: 0,
      backgroundColor: brightness == Brightness.dark
          ? const Color(0xFF15161A)
          : Colors.white,
      indicatorColor: scheme.primary.withValues(alpha: .17),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .75),
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkPanel
          : Colors.white,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black.withValues(alpha: .68),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
  );
}

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get appPanel => Theme.of(this).colorScheme.surface;
  Color get appRaised => Theme.of(this).colorScheme.surfaceContainer;
  Color get appBorder => Theme.of(this).colorScheme.outlineVariant;
  Color get appText => Theme.of(this).colorScheme.onSurface;
  Color get appMuted => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get appSoftGreen =>
      isDarkMode ? AppColors.darkSoftGreen : AppColors.softGreen;
  Color get appSoftBlue {
    final scheme = Theme.of(this).colorScheme;
    return Color.alphaBlend(
      scheme.secondary.withValues(alpha: isDarkMode ? .22 : .12),
      scheme.surface,
    );
  }

  Color get appSoftAmber =>
      isDarkMode ? const Color(0xFF3F311C) : AppColors.softAmber;
  Color get appSoftRed =>
      isDarkMode ? const Color(0xFF442521) : AppColors.softRed;
  Color get appGreenText {
    final scheme = Theme.of(this).colorScheme;
    return _accessibleAccentText(scheme.primary, scheme.surface);
  }

  Color get appBlueText {
    final scheme = Theme.of(this).colorScheme;
    return _accessibleAccentText(scheme.secondary, scheme.surface);
  }

  Color get appWarningText =>
      isDarkMode ? const Color(0xFFFFC46E) : const Color(0xFFB96500);
  Color get appDangerText =>
      isDarkMode ? const Color(0xFFFF9187) : const Color(0xFFC73B2E);
}
