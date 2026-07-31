import 'package:flutter/widgets.dart';

/// Ported verbatim from CozyDesignSystem.swift. Hex values are the contract —
/// the app and both native widgets must agree exactly or the widget looks
/// subtly wrong sitting next to the app.
class CozyColors {
  const CozyColors._();

  static const pageBackground = Color(0xFFF5EDE0);
  static const cardBackground = Color(0xFFFFFDF7);
  static const cardSecondary = Color(0xFFF8F0E5);

  static const textPrimary = Color(0xFF4A3525);
  static const textSecondary = Color(0xFF6B5545);
  static const textMuted = Color(0xFF998475);

  static const sageGreen = Color(0xFFA8C3A8);
  static const dustyPink = Color(0xFFE8B4B8);
  static const softBlue = Color(0xFF9BB7D4);
  static const softYellow = Color(0xFFF3D58C);
  static const softLavender = Color(0xFFC8B6E2);
  static const warmCoral = Color(0xFFE8927C);

  /// textPrimary at 0.08 alpha.
  static const shadow = Color(0x144A3525);
}

/// SwiftUI's `shadow(radius:)` is a Gaussian sigma; Flutter's `blurRadius` is
/// roughly 2*sigma. Every ported shadow doubles its radius, so keep the
/// conversion in one place rather than scattering magic numbers.
List<BoxShadow> cozyShadow({
  double swiftUiRadius = 12,
  double y = 6,
  Color color = CozyColors.shadow,
}) =>
    [BoxShadow(color: color, blurRadius: swiftUiRadius * 2, offset: Offset(0, y))];
