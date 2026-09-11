import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  // Light mode is intentionally cool and white rather than a warmed-up
  // inversion of the dark theme. These ink colors keep long-form text
  // readable while the four semantic families carry emphasis.
  static const navy = Color(0xFF17202A);
  static const navyMuted = Color(0xFF66717F);
  static const blue = Color(0xFF3E86C8);
  static const blueText = Color(0xFF286AA4);
  static const lightGreen = Color(0xFF36965B);
  static const greenText = Color(0xFF277A48);
  static const goldText = Color(0xFF8A620E);
  static const coralText = Color(0xFFC8463E);
  static const green = Color(0xFF0E9363);
  static const greenDark = Color(0xFF08734D);
  static const warmWhite = Color(0xFFFFFFFF);
  static const panel = Color(0xFFFFFFFF);
  static const lightSurfaceLow = Color(0xFFFAFBFD);
  static const lightSurface = Color(0xFFF6F8FB);
  static const lightSurfaceHigh = Color(0xFFEEF3F8);
  static const lightSurfaceHighest = Color(0xFFE7EDF4);
  static const border = Color(0xFFE1E6EC);
  static const softBlue = Color(0xFFDCEEFF);
  static const softGreen = Color(0xFFDDF5E5);
  static const softAmber = Color(0xFFFFF2C7);
  static const softRed = Color(0xFFFFE2DE);
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
  final dark = brightness == Brightness.dark;
  // The approved light compositions use the clear coral itself for controls
  // and selection—not a darkened brick approximation. Contrast comes from
  // the foreground placed on the coral, while coral text on white continues
  // to use the dedicated, darker semantic token below.
  final effectiveAccent = accentColor;
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
        primaryContainer: dark ? AppColors.darkRaised : AppColors.softRed,
        onPrimaryContainer: dark ? AppColors.darkText : AppColors.coralText,
        secondary: dark ? accentColor : AppColors.blue,
        onSecondary: dark ? _bestForeground(accentColor) : Colors.white,
        secondaryContainer: dark ? AppColors.darkRaised : AppColors.softBlue,
        onSecondaryContainer: dark ? AppColors.darkText : AppColors.blueText,
        tertiary: dark ? AppColors.success : AppColors.lightGreen,
        onTertiary: Colors.white,
        tertiaryContainer: dark ? AppColors.darkSoftGreen : AppColors.softGreen,
        onTertiaryContainer: dark ? AppColors.darkText : AppColors.greenText,
        surfaceContainerLowest: dark
            ? AppColors.darkBackground
            : AppColors.warmWhite,
        surfaceContainerLow: dark
            ? AppColors.darkPanel
            : AppColors.lightSurfaceLow,
        surfaceContainer: dark ? AppColors.darkRaised : AppColors.lightSurface,
        surfaceContainerHigh: dark
            ? AppColors.darkRaisedHigh
            : AppColors.lightSurfaceHigh,
        surfaceContainerHighest: dark
            ? const Color(0xFF292F33)
            : AppColors.lightSurfaceHighest,
        onSurface: brightness == Brightness.dark
            ? AppColors.darkText
            : AppColors.navy,
        onSurfaceVariant: dark ? AppColors.darkMuted : AppColors.navyMuted,
        outline: brightness == Brightness.dark
            ? AppColors.darkBorder
            : AppColors.border,
        outlineVariant: dark ? AppColors.darkBorder : AppColors.border,
        error: dark ? AppColors.danger : AppColors.coralText,
        onError: Colors.white,
        errorContainer: dark ? const Color(0xFF442521) : AppColors.softRed,
        onErrorContainer: dark ? const Color(0xFFFF9187) : AppColors.coralText,
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
      color: dark ? scheme.surface : AppColors.lightSurfaceLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: dark ? Colors.transparent : AppColors.border),
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
      fillColor: dark
          ? scheme.surfaceContainerHighest
          : AppColors.lightSurfaceLow,
      contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(
          color: dark ? accentColor : AppColors.blue,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
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
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? accentColor : AppColors.coralText,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        foregroundColor: dark ? scheme.onSurface : AppColors.blueText,
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
      foregroundColor: scheme.onSurface,
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.darkBackground,
              systemNavigationBarIconBrightness: Brightness.light,
              systemNavigationBarDividerColor: AppColors.darkBorder,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
              systemNavigationBarDividerColor: AppColors.border,
            ),
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
            ? (dark ? accentColor : AppColors.lightGreen)
            : scheme.surfaceContainerHighest,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? (dark ? accentColor : AppColors.lightGreen)
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: BorderSide(color: scheme.onSurfaceVariant, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.onSurfaceVariant,
      ),
    ),
    iconTheme: IconThemeData(
      color: dark ? scheme.onSurface : AppColors.blueText,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: dark ? scheme.onSurfaceVariant : AppColors.blueText,
      textColor: scheme.onSurface,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: dark ? scheme.surfaceContainer : AppColors.lightSurface,
      selectedColor: dark
          ? accentColor.withValues(alpha: .18)
          : AppColors.softRed,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      secondaryLabelStyle: TextStyle(
        color: dark ? scheme.onSurface : AppColors.coralText,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? AppColors.darkRaised : AppColors.lightSurfaceLow,
      surfaceTintColor: Colors.transparent,
      elevation: dark ? 8 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: dark
          ? AppColors.darkRaisedHigh
          : AppColors.lightSurfaceHigh,
      circularTrackColor: dark
          ? AppColors.darkRaisedHigh
          : AppColors.lightSurfaceHigh,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: dark ? 5 : 2,
      focusElevation: dark ? 6 : 3,
      hoverElevation: dark ? 6 : 3,
      shape: const CircleBorder(),
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
    if (!isDarkMode) return AppColors.softBlue;
    final scheme = Theme.of(this).colorScheme;
    return Color.alphaBlend(
      scheme.secondary.withValues(alpha: .22),
      scheme.surface,
    );
  }

  Color get appPending => AppColors.yellow;
  Color get appSuccess => isDarkMode ? AppColors.success : AppColors.lightGreen;
  Color get appDanger => AppColors.danger;

  Color get appSoftAmber =>
      isDarkMode ? const Color(0xFF3F311C) : AppColors.softAmber;
  Color get appSoftRed =>
      isDarkMode ? const Color(0xFF442521) : AppColors.softRed;
  Color get appGreenText {
    if (!isDarkMode) return AppColors.greenText;
    final scheme = Theme.of(this).colorScheme;
    return _accessibleAccentText(AppColors.success, scheme.surface);
  }

  Color get appBlueText {
    if (!isDarkMode) return AppColors.blueText;
    final scheme = Theme.of(this).colorScheme;
    return _accessibleAccentText(scheme.secondary, scheme.surface);
  }

  Color get appWarningText =>
      isDarkMode ? const Color(0xFFFFC46E) : AppColors.goldText;
  Color get appDangerText =>
      isDarkMode ? const Color(0xFFFF9187) : AppColors.coralText;
}
