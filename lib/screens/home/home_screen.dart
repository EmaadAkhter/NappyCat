import 'dart:async';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import '../../config.dart';
import '../../models/cat_breed.dart';
import '../../models/widget_payload.dart';
import '../../theme/cozy_colors.dart';
import '../../theme/cozy_text.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/cat_illustration.dart';
import '../../widgets/cozy_card.dart';
import '../../widgets/speech_bubble.dart';

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
    required this.onEditName,
    this.onSendText,
    this.mini = false,
  });

  /// Desktop-widget mode (web `?mini=1`): just the cat and its bubble, sized
  /// for a small pinned window. Everything else lives in the full app.
  final bool mini;

  final CatBreed myBreed;
  final String myName;
  final WidgetPayload payload;

  /// Null when there is nothing unopened to read.
  final VoidCallback? onOpenLetter;
  final VoidCallback onCompose;
  final VoidCallback onChangeCat;
  final VoidCallback onOpenJournal;
  final VoidCallback onEditName;

  /// Inline send for the widget's composer bar; returns an error line or null.
  final Future<String?> Function(String text)? onSendText;

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

    if (widget.mini) {
      // The widget is the whole app in miniature: bubble on top, the cat
      // grown into every remaining pixel, one composer bar. No cards, no
      // chrome — the window itself is the card.
      final line = switch (state) {
        LetterState.waiting => '✉️ a new letter — tap to read',
        LetterState.open => p.text ?? '',
        LetterState.faded => 'it drifted away…',
        LetterState.empty => p.idleLine ?? 'zzz…',
      };
      final awake = state == LetterState.waiting || state == LetterState.open;
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    // Windows-only drag handle: the frameless widget window
                    // can't be moved any other way — the Flutter view eats
                    // every mouse message before native hit-testing sees it.
                    if (Config.mini &&
                        !kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.windows)
                      Listener(
                        onPointerDown: (_) => unawaited(
                            const MethodChannel('nappycat/widget')
                                .invokeMethod('drag')
                                .catchError((_) => null)),
                        child: Container(
                          width: 26,
                          height: 26,
                          margin: const EdgeInsets.only(right: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: CozyColors.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: cozyShadow(swiftUiRadius: 2, y: 1),
                          ),
                          child: const Icon(Icons.drag_indicator,
                              size: 16, color: CozyColors.textMuted),
                        ),
                      ),
                    Expanded(
                      child: Bouncy(
                        onTap: widget.onEditName,
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: CozyColors.cardBackground,
                                shape: BoxShape.circle,
                                boxShadow: cozyShadow(swiftUiRadius: 3, y: 1),
                              ),
                              child: CatIllustration(
                                breed: widget.myBreed,
                                awake: true,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _greeting,
                                    style: CozyText.rounded(
                                      18,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'You are ${widget.myName} to them · tap to edit',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: CozyText.rounded(
                                      11,
                                      color: CozyColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'more',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (v) => switch (v) {
                        'journal' => widget.onOpenJournal(),
                        'cat' => widget.onChangeCat(),
                        _ => null,
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'journal',
                          child: Text('Still here'),
                        ),
                        PopupMenuItem(
                          value: 'cat',
                          child: Text('Change my cat'),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.more_horiz,
                          size: 20,
                          color: CozyColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Bouncy(
                    onTap: state == LetterState.waiting
                        ? widget.onOpenLetter
                        : null,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SpeechBubble(
                            tail: BubbleTail.down,
                            child: Text(
                              line,
                              textAlign: TextAlign.center,
                              style: CozyText.rounded(
                                15,
                                weight: FontWeight.w600,
                              ).copyWith(height: 1.35),
                            ),
                          ),
                          if (state == LetterState.waiting ||
                              state == LetterState.open)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '— $partner',
                                textAlign: TextAlign.center,
                                style: CozyText.muted,
                              ),
                            ),
                          // The tail points straight at the cat's head; the
                          // cat scales to whatever height is left.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: CatIllustration(
                                breed: p.partnerBreed,
                                awake: awake,
                                size: 330,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _MiniComposer(
                  partner: partner,
                  canSendAt: p.canSendAt,
                  now: now,
                  onSend: widget.onSendText,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Bouncy(
                onTap: widget.onEditName,
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
                        breed: widget.myBreed,
                        awake: true,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _greeting,
                            style: CozyText.rounded(
                              22,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'You are ${widget.myName} to them · tap to edit',
                            style: CozyText.rounded(
                              13,
                              color: CozyColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: CozyColors.textMuted,
                    ),
                  ],
                ),
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
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CozyText.caption,
            ),
          ),
        ],
      ),
    ),
  );
}

/// The four-state hero, comic-vertical: bubble on top with its tail pointing
/// down at the cat below. The teaser never shows the words — tapping reveals
/// the letter in place, which is what starts its 16h clock. Mirrors the widget
/// exactly.
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

  String get _line => switch (state) {
    LetterState.waiting => '✉️ a new letter — tap to read',
    LetterState.open => payload.text ?? '',
    LetterState.faded => 'it drifted away…',
    LetterState.empty => payload.idleLine ?? 'zzz…',
  };

  @override
  Widget build(BuildContext context) {
    final breed = payload.partnerBreed;
    // Awake while an unread letter waits and for the short reading window
    // after it is revealed; asleep once read.
    final awake = state == LetterState.waiting || state == LetterState.open;

    return Bouncy(
      onTap: state == LetterState.waiting ? onTap : null,
      child: CozyCard(
        padding: 20,
        radius: 32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpeechBubble(
              tail: BubbleTail.down,
              child: Text(
                _line,
                textAlign: TextAlign.center,
                style: CozyText.rounded(
                  16,
                  weight: FontWeight.w600,
                ).copyWith(height: 1.4),
              ),
            ),
            if (state == LetterState.waiting || state == LetterState.open) ...[
              const SizedBox(height: 2),
              Text(
                '— $partner',
                textAlign: TextAlign.center,
                style: CozyText.muted,
              ),
            ],
            const SizedBox(height: 6),
            Center(
              child: CatIllustration(breed: breed, awake: awake, size: 210),
            ),
          ],
        ),
      ),
    );
  }
}

/// The widget's whole control surface: a text bar with a send button, and a
/// ⋯ menu holding everything that isn't writing. While the tide is out the
/// bar itself shows the countdown, so no extra chrome appears either way.
class _MiniComposer extends StatefulWidget {
  const _MiniComposer({
    required this.partner,
    required this.canSendAt,
    required this.now,
    required this.onSend,
  });

  final String partner;
  final DateTime? canSendAt;
  final DateTime now;
  final Future<String?> Function(String text)? onSend;

  @override
  State<_MiniComposer> createState() => _MiniComposerState();
}

class _MiniComposerState extends State<_MiniComposer> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _locked =>
      widget.canSendAt != null && widget.now.isBefore(widget.canSendAt!);

  Future<void> _submit() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending || _locked || widget.onSend == null) return;
    setState(() => _sending = true);
    final error = await widget.onSend!(body);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _text.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = !_locked && widget.onSend != null;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: CozyColors.cardBackground,
              borderRadius: BorderRadius.circular(22),
              boxShadow: cozyShadow(swiftUiRadius: 3, y: 1),
            ),
            child: canWrite
                ? Center(
                    child: TextField(
                      controller: _text,
                      onSubmitted: (_) => _submit(),
                      textInputAction: TextInputAction.send,
                      maxLength: 500,
                      style: CozyText.rounded(14),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        counterText: '',
                        hintText: 'write to ${widget.partner}…',
                        hintStyle: CozyText.rounded(
                          14,
                          color: CozyColors.textMuted,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🐾 ', style: TextStyle(fontSize: 13)),
                        Flexible(
                          child: Text(
                            'next letter in ${_remaining(widget.canSendAt!, widget.now)}',
                            overflow: TextOverflow.ellipsis,
                            style: CozyText.rounded(
                              13,
                              color: CozyColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Bouncy(
          onTap: canWrite && !_sending ? _submit : null,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: canWrite
                  ? CozyColors.dustyPink
                  : CozyColors.cardBackground,
              shape: BoxShape.circle,
              boxShadow: cozyShadow(swiftUiRadius: 3, y: 1),
            ),
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.send_rounded,
                    size: 18,
                    color: canWrite
                        ? CozyColors.textPrimary
                        : CozyColors.textMuted,
                  ),
          ),
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
            child: const Text('🐾', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locked ? 'The cat is napping' : 'The cat is ready',
                  style: CozyText.rounded(16, weight: FontWeight.w700),
                ),
                Text(
                  locked
                      ? 'You can write again in ${_remaining(canSendAt!, now)}'
                      : 'It can carry a letter now',
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
