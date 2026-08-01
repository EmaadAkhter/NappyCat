import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/cat_breed.dart';
import '../../models/tidal_message.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/cat_illustration.dart';
import '../../widgets/speech_bubble.dart';

/// Reading a letter. The cat is awake only here, for exactly as long as you
/// are reading — closing this screen puts it back to sleep. The letter itself
/// stays findable in the journal until it fades.
class LetterScreen extends StatefulWidget {
  const LetterScreen({
    super.key,
    required this.letter,
    required this.openedAt,
    required this.now,
  });

  final TidalMessage letter;
  final DateTime openedAt;
  final DateTime Function() now;

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.letter;
    final breed = CatBreed.fromId(l.senderCatId);
    final expiresAt = l.expiresAt;
    final now = widget.now();
    final gone = expiresAt != null && !now.isBefore(expiresAt);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              CatIllustration(breed: breed, awake: !gone, size: 170),
              const SizedBox(height: 16),
              if (gone)
                Text('It faded away',
                    style: CozyText.rounded(22, weight: FontWeight.w700))
              else ...[
                SpeechBubble(
                  child: Text(
                    l.text,
                    textAlign: TextAlign.center,
                    style: CozyText.rounded(18, weight: FontWeight.w600)
                        .copyWith(height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '— ${l.senderName ?? 'them'}'
                  '${expiresAt == null ? '' : ' · fades in ${_remaining(expiresAt, now)}'}',
                  style: CozyText.muted,
                ),
              ],
              const Spacer(),
              CozyButton(
                title: 'Done 🐾',
                icon: Icons.check,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 4),
              Text(
                gone
                    ? 'Letters only stay a little while.'
                    : "It'll rest in 'Still here' until it fades.",
                style: CozyText.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _remaining(DateTime target, DateTime now) {
  var d = target.difference(now);
  if (d.isNegative) d = Duration.zero;
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}
