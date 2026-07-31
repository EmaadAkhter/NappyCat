import 'package:flutter/material.dart';
import '../models/cat_breed.dart';

/// Port of CatIllustrationView. The Swift version had a hand-drawn CustomPaint
/// fallback for when the PNG was missing; all 16 assets ship, so that path was
/// dead in production and is not carried over.
///
/// ponytail: no vector fallback. If an asset is ever genuinely missing the
/// errorBuilder shows an empty box rather than reimplementing ~250 lines of
/// shape maths for a case that cannot occur.
class CatIllustration extends StatelessWidget {
  const CatIllustration({
    super.key,
    required this.breed,
    this.awake = false,
    this.size = 160,
  });

  final CatBreed breed;
  final bool awake;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          breed.assetFor(awake: awake),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
}
