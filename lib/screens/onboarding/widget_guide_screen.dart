import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../models/cat_breed.dart';
import '../../theme/cozy_colors.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/cat_illustration.dart';
import '../../widgets/cozy_card.dart';

/// Port of WidgetGuideView, forked per platform — the install gesture genuinely
/// differs and generic copy would be wrong on both.
class WidgetGuideScreen extends StatelessWidget {
  const WidgetGuideScreen({
    super.key,
    required this.breed,
    required this.onFinish,
  });

  final CatBreed breed;
  final VoidCallback onFinish;

  List<(String, String, String, Color)> get _steps => Platform.isIOS
      ? const [
          ('1', 'Long-Press Home Screen',
              'Touch and hold any empty area until the icons jiggle.',
              CozyColors.softYellow),
          ('2', "Tap '+' & Search",
              "Tap '+' in the top corner and search for 'Tidal'.",
              CozyColors.dustyPink),
          ('3', 'Add Widget & Tap to Read',
              'Pick Small or Medium, place it, and tap when a letter arrives.',
              CozyColors.sageGreen),
        ]
      : const [
          ('1', 'Long-Press Home Screen',
              'Touch and hold any empty area on your home screen.',
              CozyColors.softYellow),
          ('2', "Tap 'Widgets'",
              "Choose 'Widgets' from the menu, then find 'Tidal'.",
              CozyColors.dustyPink),
          ('3', 'Drag It Home & Tap to Read',
              'Drag the widget onto your screen and tap when a letter arrives.',
              CozyColors.sageGreen),
        ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text('Add Your Widget 📱',
                  style: CozyText.rounded(28, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Their cat will sleep on your home screen until a letter arrives',
                  textAlign: TextAlign.center,
                  style: CozyText.body,
                ),
              ),
              const SizedBox(height: 20),
              CozyCard(
                padding: 16,
                child: CatIllustration(breed: breed, size: 120),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    for (final (n, title, sub, color) in _steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GuideStep(
                            number: n, title: title, subtitle: sub, color: color),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: CozyButton(
                  title: 'Got It! Take Me Home 🐾',
                  icon: Icons.arrow_forward,
                  onTap: onFinish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String number;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => DashedCard(
        padding: 14,
        radius: 18,
        strokeColor: color,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(number,
                  style: CozyText.rounded(18, weight: FontWeight.w900)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: CozyText.rounded(16, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: CozyText.caption),
                ],
              ),
            ),
          ],
        ),
      );
}
