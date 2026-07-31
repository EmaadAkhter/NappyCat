import 'package:flutter/material.dart';
import '../../models/cat_breed.dart';
import '../../theme/cozy_colors.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/cat_illustration.dart';

/// Port of CatSelectionView. Tapping a card only selects it; the footer button
/// commits, exactly as in the Swift original.
///
/// Meaning shifts here: the cat you pick is your identity to the person you're
/// paired with — it's the cat that will sleep on *their* home screen.
class CatSelectionScreen extends StatefulWidget {
  const CatSelectionScreen({
    super.key,
    required this.onSelected,
    this.initial = CatBreed.tabby,
  });

  final ValueChanged<CatBreed> onSelected;
  final CatBreed initial;

  @override
  State<CatSelectionScreen> createState() => _CatSelectionScreenState();
}

class _CatSelectionScreenState extends State<CatSelectionScreen> {
  late CatBreed _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PastelIconBadge(icon: Icons.pets),
                const SizedBox(width: 10),
                Flexible(
                  child: Text('Adopt Your Nap Cat',
                      style: CozyText.rounded(26, weight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Choose a cozy hooded companion to carry your letters ✨',
                textAlign: TextAlign.center,
                style: CozyText.body,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: CatBreed.values.length,
                itemBuilder: (_, i) {
                  final breed = CatBreed.values[i];
                  return _BreedCard(
                    breed: breed,
                    selected: breed == _selected,
                    onTap: () => setState(() => _selected = breed),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: CozyButton(
                title: 'Adopt ${_selected.label}',
                icon: Icons.favorite,
                background: _selected.accent,
                onTap: () => widget.onSelected(_selected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreedCard extends StatelessWidget {
  const _BreedCard({
    required this.breed,
    required this.selected,
    required this.onTap,
  });

  final CatBreed breed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Bouncy(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CozyColors.cardBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? breed.accent : Colors.transparent,
              width: selected ? 3.5 : 0,
            ),
            boxShadow: selected
                ? cozyShadow(
                    swiftUiRadius: 10, y: 4, color: breed.accent.withValues(alpha: 0.3))
                : cozyShadow(swiftUiRadius: 6, y: 2),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: breed.accent.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(breed.hoodLabel,
                      style: CozyText.rounded(11, weight: FontWeight.w700)),
                ),
              ),
              Expanded(
                child: CatIllustration(breed: breed, awake: true, size: 100),
              ),
              Text(
                breed.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CozyText.rounded(16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 32,
                child: Text(
                  breed.personality,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CozyText.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
