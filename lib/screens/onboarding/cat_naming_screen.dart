import 'package:flutter/material.dart';
import '../../models/cat_breed.dart';
import '../../theme/cozy_colors.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/cat_illustration.dart';
import '../../widgets/cozy_card.dart';

const kMaxNameLength = 20;

/// Port of CatNamingView.
///
/// One identity, not two: the Swift app named a pet, but here the name is how
/// your partner sees you, so "cat name" and "your name" are collapsed into a
/// single field rather than shipping two competing identity concepts.
class CatNamingScreen extends StatefulWidget {
  const CatNamingScreen({
    super.key,
    required this.breed,
    required this.onConfirmed,
    this.initialName = '',
  });

  final CatBreed breed;
  final ValueChanged<String> onConfirmed;
  final String initialName;

  @override
  State<CatNamingScreen> createState() => _CatNamingScreenState();
}

class _CatNamingScreenState extends State<CatNamingScreen> {
  late final _controller = TextEditingController(text: widget.initialName);
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    widget.onConfirmed(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final count = _controller.text.characters.length;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text('Name Your Cat 🐾',
                  style: CozyText.rounded(28, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Your ${widget.breed.label} carries this name to them',
                  style: CozyText.body, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: CozyCard(
                  padding: 24,
                  radius: 28,
                  child: Column(
                    children: [
                      CatIllustration(
                          breed: widget.breed, awake: true, size: 160),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.breed.accent.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(widget.breed.hoodLabel,
                            style:
                                CozyText.rounded(12, weight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CozyCard(
                  radius: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('NAME',
                              style: CozyText.rounded(12,
                                  weight: FontWeight.w700,
                                  color: CozyColors.textMuted)),
                          Text('$count/$kMaxNameLength',
                              style: CozyText.rounded(12,
                                  weight: FontWeight.w700,
                                  color: CozyColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CozyColors.cardSecondary,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _showError
                                ? Colors.red
                                : CozyColors.sageGreen.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined,
                                color: CozyColors.sageGreen, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                maxLength: kMaxNameLength,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                                onChanged: (_) =>
                                    setState(() => _showError = false),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  hintText: 'Your name',
                                ),
                                style: CozyText.rounded(18,
                                    weight: FontWeight.w600),
                              ),
                            ),
                            if (_controller.text.isNotEmpty)
                              GestureDetector(
                                onTap: () => setState(_controller.clear),
                                child: const Icon(Icons.cancel,
                                    color: CozyColors.textMuted, size: 20),
                              ),
                          ],
                        ),
                      ),
                      if (_showError) ...[
                        const SizedBox(height: 8),
                        Text('Please enter a name 🐱',
                            style: CozyText.rounded(13, color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CozyButton(
                  title: 'Confirm & Adopt 🐾',
                  icon: Icons.check_circle,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
