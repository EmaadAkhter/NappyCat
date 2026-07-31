import 'package:flutter/material.dart';
import 'cozy_colors.dart';

/// Deliberately thin. This design is card- and illustration-driven, not
/// Material-component-driven, so the real system lives in CozyColors +
/// lib/widgets/. ThemeData only has to cover the handful of Material widgets we
/// actually touch (TextField, SnackBar, page transitions).
///
/// Light-mode only, like the Swift original — the palette is literal, not
/// adaptive, so dark mode would render it wrong. `themeMode: light` in the app
/// plus UIUserInterfaceStyle=Light in Info.plist is what pins it.
ThemeData buildCozyTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: CozyColors.pageBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CozyColors.sageGreen,
      brightness: Brightness.light,
      surface: CozyColors.cardBackground,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Nunito',
      bodyColor: CozyColors.textPrimary,
      displayColor: CozyColors.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
  );
}
