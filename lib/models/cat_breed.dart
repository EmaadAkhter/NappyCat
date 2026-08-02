import 'package:flutter/widgets.dart';

/// Direct port of CatBreed.swift. Declaration order is grid order.
///
/// Note the labels are intentionally mismatched with a couple of the ids
/// (`blueberry` reads "Orange Tabby", `pumpkin` reads "Cream Cat") — that is how
/// the artwork was drawn, so it is preserved verbatim rather than "fixed".
enum CatBreed {
  tabby('Grey Tabby', 'Cheese Hood 🧀', 0xFFF4C430,
      'Loves cozy napping and gourmet cheese slices.'),
  tuxedo('B&W Tuxedo', 'Chicken Hood 🍗', 0xFFE8927C,
      'Dapper & polite, but obsessed with snack time.'),
  ginger('White Cat', 'Tomato Hood 🍅', 0xFFE05A47,
      'Warm, energetic, and spicy like fresh tomato soup.'),
  pumpkin('Cream Cat', 'Pumpkin Hood 🎃', 0xFFE88735,
      'Sweet, gentle, and loves warm autumn sunbeams.'),
  koala('Panda/Koala Cat', 'Koala Hood 🐨', 0xFF8AA899,
      'Sleepy 23 hours a day, super cuddly and soft.'),
  jester('Jester Tuxedo', 'Jester Hood 🃏', 0xFF9B6B9E,
      'Playful prankster who loves silly antics.'),
  blueberry('Orange Tabby', 'Blueberry Hood 🫐', 0xFF5C85C7,
      'Curious explorer with a berry sweet heart.'),
  catear('Grey & White Cat', 'Cat-Ear Hood 🐱', 0xFFD4829E,
      'Double cat power! Extra purrs & gentle meows.');

  const CatBreed(this.label, this.hoodLabel, this._accent, this.personality);

  final String label;
  final String hoodLabel;
  final int _accent;
  final String personality;

  /// Stable identifier persisted to Firestore and shared with the native widgets.
  String get id => name;

  Color get accent => Color(_accent);

  String assetFor({required bool awake}) =>
      'assets/cats/$name${awake ? '_awake' : '_asleep'}.png';

  /// Unknown ids fall back to tabby rather than throwing — a widget or a stale
  /// Firestore doc must never be able to crash a screen.
  static CatBreed fromId(String? id) =>
      CatBreed.values.firstWhere((b) => b.name == id, orElse: () => CatBreed.tabby);
}
