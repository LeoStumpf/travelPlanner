import 'package:flutter/material.dart';

/// "Fahrplan" design: black, white and signal yellow, bold system type,
/// planning layers as transit line colours. Only system fonts are used.
class Tokens {
  static const black = Color(0xFF0B0D12);
  static const white = Color(0xFFFFFFFF);
  static const signal = Color(0xFFFFC21A);
  static const surfaceLight = Color(0xFFF1F2F4);
  static const lineLight = Color(0xFFD5D8DE);
  static const mutedLight = Color(0xFF50565F);

  static const groundDark = Color(0xFF0B0D12);
  static const surfaceDark = Color(0xFF171A21);
  static const raisedDark = Color(0xFF22262F);
  static const lineDark = Color(0xFF353A45);
  static const mutedDark = Color(0xFFA9AFB8);
}

/// Colours the Material scheme has no slot for.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Signal yellow for warnings like "night without a bed".
  final Color signal;
  final Color onSignal;
  final Color line;
  final Color muted;

  /// Night shading in the timeline.
  final Color night;

  const AppColors({
    required this.signal,
    required this.onSignal,
    required this.line,
    required this.muted,
    required this.night,
  });

  /// Falls back to the light values outside the app theme (e.g. in tests).
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      const AppColors(
        signal: Tokens.signal,
        onSignal: Tokens.black,
        line: Tokens.lineLight,
        muted: Tokens.mutedLight,
        night: Tokens.surfaceLight,
      );

  @override
  AppColors copyWith({Color? signal, Color? onSignal, Color? line, Color? muted, Color? night}) => AppColors(
        signal: signal ?? this.signal,
        onSignal: onSignal ?? this.onSignal,
        line: line ?? this.line,
        muted: muted ?? this.muted,
        night: night ?? this.night,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      signal: Color.lerp(signal, other.signal, t)!,
      onSignal: Color.lerp(onSignal, other.onSignal, t)!,
      line: Color.lerp(line, other.line, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      night: Color.lerp(night, other.night, t)!,
    );
  }
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final ink = dark ? Tokens.white : Tokens.black;
  final ground = dark ? Tokens.groundDark : Tokens.white;
  final surface = dark ? Tokens.surfaceDark : Tokens.surfaceLight;
  final line = dark ? Tokens.lineDark : Tokens.lineLight;
  final muted = dark ? Tokens.mutedDark : Tokens.mutedLight;

  final scheme = ColorScheme.fromSeed(seedColor: Tokens.signal, brightness: b).copyWith(
    primary: dark ? Tokens.signal : Tokens.black,
    onPrimary: dark ? Tokens.black : Tokens.white,
    primaryContainer: Tokens.signal,
    onPrimaryContainer: Tokens.black,
    secondary: Tokens.signal,
    onSecondary: Tokens.black,
    secondaryContainer: dark ? Tokens.raisedDark : Tokens.surfaceLight,
    onSecondaryContainer: ink,
    tertiary: const Color(0xFF1F5FD1),
    surface: ground,
    onSurface: ink,
    onSurfaceVariant: muted,
    surfaceContainerLowest: ground,
    surfaceContainerLow: dark ? Tokens.surfaceDark : const Color(0xFFF7F8F9),
    surfaceContainer: surface,
    surfaceContainerHigh: dark ? Tokens.raisedDark : const Color(0xFFE9EBEE),
    surfaceContainerHighest: dark ? Tokens.lineDark : const Color(0xFFE1E4E8),
    outline: dark ? Tokens.mutedDark : Tokens.mutedLight,
    outlineVariant: line,
    error: dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828),
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: b);
  final t = base.textTheme;
  final text = t.copyWith(
    displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.5),
    headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
    headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.4),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    labelSmall: t.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
  ).apply(bodyColor: ink, displayColor: ink);

  const stadium = StadiumBorder();
  return base.copyWith(
    scaffoldBackgroundColor: ground,
    textTheme: text,
    extensions: [
      AppColors(
        signal: Tokens.signal,
        onSignal: Tokens.black,
        line: line,
        muted: muted,
        night: dark ? const Color(0xFF12151B) : const Color(0xFFF1F2F4),
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: ground,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ink, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: stadium,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: stadium,
        foregroundColor: ink,
        side: BorderSide(color: ink, width: 2),
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: dark ? Tokens.signal : Tokens.black,
      foregroundColor: dark ? Tokens.black : Tokens.signal,
      shape: stadium,
      elevation: 2,
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: line, width: 1.5),
      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: ink),
      secondaryLabelStyle: TextStyle(fontWeight: FontWeight.w700, color: ink),
      iconTheme: IconThemeData(color: ink, size: 18),
      selectedColor: dark ? Tokens.raisedDark : Tokens.surfaceLight,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Tokens.black,
      indicatorColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? Tokens.signal : Tokens.mutedDark,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w900 : FontWeight.w700,
            color: s.contains(WidgetState.selected) ? Tokens.signal : Tokens.mutedDark,
          )),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: ground,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Tokens.black,
      contentTextStyle: const TextStyle(color: Tokens.white, fontWeight: FontWeight.w600),
      actionTextColor: Tokens.signal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ink, width: 2),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: Tokens.signal,
        selectedForegroundColor: Tokens.black,
        side: BorderSide(color: ink, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1),
  );
}
