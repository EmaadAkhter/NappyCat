import 'package:flutter/widgets.dart';
import 'cozy_colors.dart';

/// Every text style in the Swift app was `.system(size:weight:design:.rounded)`.
/// Nunito is the stand-in for SF Pro Rounded — it keeps the warmth and stays
/// legible at the 9-13px sizes the home-screen widget uses.
class CozyText {
  const CozyText._();

  static TextStyle _n(double size, FontWeight weight, Color color) => TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.25,
      );

  static TextStyle rounded(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = CozyColors.textPrimary,
  }) =>
      _n(size, weight, color);

  // Named styles for the shapes that repeat across screens.
  static TextStyle get screenTitle => _n(28, FontWeight.w700, CozyColors.textPrimary);
  static TextStyle get sectionTitle => _n(17, FontWeight.w700, CozyColors.textPrimary);
  static TextStyle get body => _n(15, FontWeight.w500, CozyColors.textSecondary);
  static TextStyle get caption => _n(13, FontWeight.w500, CozyColors.textSecondary);
  static TextStyle get muted => _n(12, FontWeight.w500, CozyColors.textMuted);
  static TextStyle get pill => _n(13, FontWeight.w700, CozyColors.textPrimary);
}
