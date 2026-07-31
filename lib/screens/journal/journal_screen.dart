import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/cat_breed.dart';
import '../../models/tidal_message.dart';
import '../../theme/cozy_colors.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/cat_illustration.dart';
import '../../widgets/cozy_card.dart';

/// Everything still alive, both directions.
///
/// There is no archive: this is the live query with client-side expiry applied,
/// so the journal empties itself as letters fade. That is the whole point — the
/// app never quietly keeps a copy of something it told you was gone.
class JournalScreen extends StatefulWidget {
  const JournalScreen({
    super.key,
    required this.messages,
    required this.myId,
    required this.myBreed,
    required this.now,
  });

  final Stream<List<TidalMessage>> messages;
  final String myId;
  final CatBreed myBreed;
  final DateTime Function() now;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: CozyColors.pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Still here',
            style: CozyText.rounded(18, weight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<TidalMessage>>(
        stream: widget.messages,
        builder: (context, snap) {
          final all = snap.data ?? const <TidalMessage>[];
          final now = widget.now();
          final visible = all.where((m) => m.isVisibleAt(now)).toList();

          if (visible.isEmpty) return _empty();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _Row(
              message: visible[i],
              mine: visible[i].senderId == widget.myId,
              myBreed: widget.myBreed,
              now: now,
            ),
          );
        },
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CatIllustration(breed: widget.myBreed, size: 120),
              const SizedBox(height: 12),
              Text('Nothing here right now',
                  style: CozyText.rounded(18, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Letters live here until they fade. An empty page means you are '
                'both caught up.',
                textAlign: TextAlign.center,
                style: CozyText.caption,
              ),
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.message,
    required this.mine,
    required this.myBreed,
    required this.now,
  });

  final TidalMessage message;
  final bool mine;
  final CatBreed myBreed;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final breed = mine ? myBreed : CatBreed.fromId(message.senderCatId);
    final who = mine ? 'You' : (message.senderName ?? 'Them');

    // An unopened letter addressed to me must never leak its text here — that
    // is the same rule the widget follows, and this is one of the three
    // surfaces where a body could escape.
    final hidden = !mine && !message.isOpened;

    return CozyCard(
      padding: 14,
      radius: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CatIllustration(breed: breed, awake: !hidden, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(who,
                        style: CozyText.rounded(14, weight: FontWeight.w700)),
                    Text(_status(), style: CozyText.rounded(11,
                        weight: FontWeight.w600, color: CozyColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CozyColors.cardSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: CozyColors.sageGreen.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    hidden ? 'Unopened — tap your cat to read it' : message.text,
                    style: hidden
                        ? CozyText.rounded(14,
                            color: CozyColors.textMuted)
                        : CozyText.rounded(14, weight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _status() {
    if (!message.isOpened) return mine ? 'unopened' : 'waiting';
    final exp = message.expiresAt;
    if (exp == null) return 'opened';
    var d = exp.difference(now);
    if (d.isNegative) d = Duration.zero;
    if (d.inHours >= 1) return 'fades in ${d.inHours}h';
    if (d.inMinutes >= 1) return 'fades in ${d.inMinutes}m';
    return 'fading…';
  }
}
