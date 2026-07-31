import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/cat_breed.dart';
import '../../models/widget_payload.dart';
import '../../theme/cozy_colors.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/cat_illustration.dart';
import '../../widgets/cozy_card.dart';

/// Port of HomeDashboardView, reworked around letters instead of quotes.
///
/// The hero card shows the PARTNER's cat — the widget is "them, on your home
/// screen", asleep when quiet and awake when they've spoken. Your own cat is the
/// small header avatar, and it's what they see on their side.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.myBreed,
    required this.myName,
    required this.payload,
    required this.onOpenLetter,
    required this.onCompose,
    required this.onChangeCat,
    required this.onOpenJournal,
  });

  final CatBreed myBreed;
  final String myName;
  final WidgetPayload payload;

  /// Null when there is nothing unopened to read.
  final VoidCallback? onOpenLetter;
  final VoidCallback onCompose;
  final VoidCallback onChangeCat;
  final VoidCallback onOpenJournal;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Countdowns and the open->faded flip are time-driven, so repaint each
    // second rather than trusting the state we were handed.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning!';
    if (h < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final p = widget.payload;
    final state = p.effectiveState(now);
    final partner = p.partnerName ?? 'your person';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: CozyColors.cardBackground,
                      shape: BoxShape.circle,
                      boxShadow: cozyShadow(swiftUiRadius: 4, y: 2),
                    ),
                    child: CatIllustration(
                        breed: widget.myBreed, awake: true, size: 40),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting,
                            style:
                                CozyText.rounded(22, weight: FontWeight.w700)),
                        Text('You are ${widget.myName} to them 💕',
                            style: CozyText.rounded(13,
                                color: CozyColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                children: [
                  _HeroLetterCard(
                    state: state,
                    payload: p,
                    partner: partner,
                    onTap: state == LetterState.waiting
                        ? widget.onOpenLetter
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _TideCard(canSendAt: p.canSendAt, now: now),
                  const SizedBox(height: 20),
                  CozyButton(
                    title: p.canSendAt == null || !now.isBefore(p.canSendAt!)
                        ? 'Write to $partner'
                        : 'Next letter in ${_remaining(p.canSendAt!, now)}',
                    icon: Icons.edit,
                    background: CozyColors.dustyPink,
                    onTap: p.canSendAt == null || !now.isBefore(p.canSendAt!)
                        ? widget.onCompose
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.menu_book,
                          label: 'Still here',
                          onTap: widget.onOpenJournal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SmallAction(
                          icon: Icons.autorenew,
                          label: 'Change my cat',
                          onTap: widget.onChangeCat,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Bouncy(
        onTap: onTap,
        child: DashedCard(
          padding: 12,
          strokeColor: CozyColors.softLavender,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: CozyColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CozyText.caption),
              ),
            ],
          ),
        ),
      );
}

/// The four-state hero. Mirrors exactly what the home-screen widget renders, so
/// this doubles as the fast iteration loop for widget layout.
class _HeroLetterCard extends StatelessWidget {
  const _HeroLetterCard({
    required this.state,
    required this.payload,
    required this.partner,
    this.onTap,
  });

  final LetterState state;
  final WidgetPayload payload;
  final String partner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final breed = payload.partnerBreed;
    final awake = state == LetterState.open;

    return Bouncy(
      onTap: onTap,
      child: CozyCard(
        padding: 24,
        radius: 32,
        child: Column(
          children: [
            CatIllustration(breed: breed, awake: awake, size: 180),
            const SizedBox(height: 12),
            switch (state) {
              LetterState.empty => _Quiet(
                  title: 'All quiet',
                  body: payload.idleLine ?? 'Your cat is napping.',
                ),
              LetterState.waiting => _Quiet(
                  title: '$partner left you something',
                  body: 'Tap to read it. The letter fades 16 hours after you open it.',
                  accent: CozyColors.softYellow,
                ),
              LetterState.open => _OpenLetter(payload: payload, partner: partner),
              LetterState.faded => _Quiet(
                  title: 'It drifted away',
                  body: 'That letter has faded. Write back when you\'re ready.',
                ),
            },
          ],
        ),
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet({required this.title, required this.body, this.accent});

  final String title;
  final String body;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (accent != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: accent!.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('✉️ a letter is waiting', style: CozyText.pill),
            ),
          Text(title,
              textAlign: TextAlign.center,
              style: CozyText.rounded(22, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: CozyText.caption),
        ],
      );
}

class _OpenLetter extends StatelessWidget {
  const _OpenLetter({required this.payload, required this.partner});

  final WidgetPayload payload;
  final String partner;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CozyColors.cardSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: CozyColors.sageGreen.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Text(payload.text ?? '',
              textAlign: TextAlign.center,
              style: CozyText.rounded(16, weight: FontWeight.w600)),
        ),
        const SizedBox(height: 10),
        Text(
          payload.expiresAt == null
              ? '— $partner'
              : '— $partner · fades in ${_remaining(payload.expiresAt!, now)}',
          style: CozyText.muted,
        ),
      ],
    );
  }
}

/// Port of the streak card's slot. "Visit streak" measured nothing once the cat
/// stopped dispensing quotes, so the same warm-coral dashed card now shows the
/// send window.
class _TideCard extends StatelessWidget {
  const _TideCard({required this.canSendAt, required this.now});

  final DateTime? canSendAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final locked = canSendAt != null && now.isBefore(canSendAt!);
    return DashedCard(
      padding: 12,
      radius: 20,
      strokeColor: CozyColors.warmCoral,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: CozyColors.warmCoral.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: const Text('🌊', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(locked ? 'The tide is out' : 'The tide is in',
                    style: CozyText.rounded(16, weight: FontWeight.w700)),
                Text(
                  locked
                      ? 'You can write again in ${_remaining(canSendAt!, now)}'
                      : 'You can send a letter now',
                  style: CozyText.muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Coarse, human countdown: "5h 12m", "48s". Deliberately not second-precise at
/// hour scale — this app is about slowing down.
String _remaining(DateTime target, DateTime now) {
  var d = target.difference(now);
  if (d.isNegative) d = Duration.zero;
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}
