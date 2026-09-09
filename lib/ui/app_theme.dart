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
  // Warm, low-contrast layers keep the interface quiet and let content lead.
  static const darkBackground = Color(0xFF0C1114);
  static const darkPanel = Color(0xFF11171B);
  static const darkRaised = Color(0xFF1B2125);
  static const darkRaisedHigh = Color(0xFF22282C);
  static const darkBorder = Color(0xFF30383D);
  static const darkText = Color(0xFFF3F4F1);
  static const darkMuted = Color(0xFFA6AAAB);
  static const darkSoftGreen = Color(0xFF13271C);
  static const darkSoftBlue = Color(0xFF20211E);
  static const yellow = Color(0xFFE0B84F);
  static const success = Color(0xFF45A36B);
  static const danger = Color(0xFFD95A57);
  static const coral = Color(0xFFFF7467);
}

/// Shared motion for the app: short, calm transitions that keep spatial
/// context without making the interface feel busy.
abstract final class LifeMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const deliberate = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;
}

class _LifePageTransitionsBuilder extends PageTransitionsBuilder {
  const _LifePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == Navigator.defaultRouteName ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final eased = CurvedAnimation(
      parent: animation,
      curve: LifeMotion.curve,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .018),
          end: Offset.zero,
        ).animate(eased),
        child: ScaleTransition(
          scale: Tween<double>(begin: .992, end: 1).animate(eased),
          child: child,
        ),
      ),
    );
  }
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
  Color accentColor = AppColors.coral,
}) {
  final complementary = _complementaryColor(accentColor);
  final dark = brightness == Brightness.dark;
  final effectiveAccent = dark ? accentColor : AppColors.navy;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
        surface: brightness == Brightness.dark
            ? AppColors.darkPanel
            : AppColors.warmWhite,
      ).copyWith(
        primary: effectiveAccent,
        onPrimary: _bestForeground(effectiveAccent),
        secondary: dark ? accentColor : complementary,
        secondaryContainer: dark
            ? AppColors.darkRaised
            : const Color(0xFFF0EEE8),
        onSecondaryContainer: dark ? AppColors.darkText : AppColors.navy,
        surfaceContainerLowest: dark
            ? AppColors.darkBackground
            : AppColors.warmWhite,
        surfaceContainerLow: dark
            ? AppColors.darkPanel
            : const Color(0xFFF4F2ED),
        surfaceContainer: dark ? AppColors.darkRaised : const Color(0xFFF0EEE8),
        surfaceContainerHigh: dark
            ? AppColors.darkRaisedHigh
            : const Color(0xFFEAE7E0),
        surfaceContainerHighest: dark
            ? const Color(0xFF292F33)
            : const Color(0xFFE6E3DC),
        onSurface: brightness == Brightness.dark
            ? AppColors.darkText
            : AppColors.navy,
        onSurfaceVariant: dark ? AppColors.darkMuted : AppColors.navyMuted,
        outline: brightness == Brightness.dark
            ? AppColors.darkBorder
            : AppColors.border,
        outlineVariant: dark ? AppColors.darkBorder : AppColors.border,
        error: AppColors.danger,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? AppColors.darkBackground
        : AppColors.warmWhite,
    fontFamily: 'Segoe UI Variable',
    visualDensity: VisualDensity.standard,
  );
  return base.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _LifePageTransitionsBuilder(),
        TargetPlatform.iOS: _LifePageTransitionsBuilder(),
        TargetPlatform.macOS: _LifePageTransitionsBuilder(),
        TargetPlatform.windows: _LifePageTransitionsBuilder(),
        TargetPlatform.linux: _LifePageTransitionsBuilder(),
      },
    ),
    textTheme: base.textTheme.copyWith(
      displaySmall: TextStyle(
        color: scheme.onSurface,
        fontSize: 26,
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
        fontSize: 16,
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
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          ? AppColors.darkPanel
          : Colors.white,
      indicatorColor: Colors.transparent,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF232427) : const Color(0xFF202124),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : scheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accentColor
            : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
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

  Color get appPending => AppColors.yellow;
  Color get appSuccess => AppColors.success;
  Color get appDanger => AppColors.danger;

  Color get appSoftAmber =>
      isDarkMode ? const Color(0xFF3F311C) : AppColors.softAmber;
  Color get appSoftRed =>
      isDarkMode ? const Color(0xFF442521) : AppColors.softRed;
  Color get appGreenText {
    final scheme = Theme.of(this).colorScheme;
    return _accessibleAccentText(AppColors.success, scheme.surface);
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
