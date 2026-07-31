import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config.dart';
import 'models/cat_breed.dart';
import 'models/tidal_message.dart';
import 'models/widget_payload.dart';
import 'screens/compose/compose_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/journal/journal_screen.dart';
import 'screens/onboarding/cat_naming_screen.dart';
import 'screens/onboarding/cat_selection_screen.dart';
import 'screens/onboarding/widget_guide_screen.dart';
import 'screens/pairing/pairing_screen.dart';
import 'services/auth_service.dart';
import 'services/idle_chatter.dart';
import 'services/services.dart';
import 'theme/cozy_colors.dart';
import 'theme/cozy_text.dart';
import 'theme/cozy_theme.dart';

class TidalApp extends StatelessWidget {
  const TidalApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      title: 'Tidal',
      debugShowCheckedModeBanner: false,
      theme: buildCozyTheme(),
      darkTheme: buildCozyTheme(),
      themeMode: ThemeMode.light,
      home: const _Root(),
    );
  }
}

/// Routes on account state: signed out -> no profile -> unpaired -> home.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  String? _uid;
  Object? _fatal;

  // Onboarding stays local until the profile is written, so abandoning it
  // halfway leaves nothing behind in Firestore.
  CatBreed _draftBreed = CatBreed.tabby;
  bool _naming = false;
  bool _showedGuide = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final user = await services.auth.signIn();
      await services.clock.sync(user.uid);
      if (mounted) setState(() => _uid = user.uid);
    } catch (e) {
      if (mounted) setState(() => _fatal = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fatal != null) return _Fatal(error: _fatal!);
    if (_uid == null) return const _Loading();

    return StreamBuilder<AppUser?>(
      stream: services.auth.watch(_uid!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final me = snap.data;

        if (me == null) {
          return _naming
              ? CatNamingScreen(
                  breed: _draftBreed,
                  onConfirmed: (name) async {
                    await services.auth.saveProfile(
                      uid: _uid!,
                      displayName: name,
                      catId: _draftBreed.id,
                    );
                    if (mounted) setState(() => _naming = false);
                  },
                )
              : CatSelectionScreen(
                  initial: _draftBreed,
                  onSelected: (b) => setState(() {
                    _draftBreed = b;
                    _naming = true;
                  }),
                );
        }

        if (!me.isPaired) {
          return PairingScreen(
            uid: _uid!,
            pairing: services.pairing,
            onPaired: (_) {}, // the user-doc stream re-routes on its own
          );
        }

        if (!_showedGuide) {
          return WidgetGuideScreen(
            breed: CatBreed.fromId(me.catId),
            onFinish: () => setState(() => _showedGuide = true),
          );
        }

        return _Home(me: me);
      },
    );
  }
}

/// Home, driven by the two live queries and composed into the same
/// [WidgetPayload] the native widgets will read — so the in-app hero card and
/// the home-screen widget can never disagree about what the cat is doing.
class _Home extends StatelessWidget {
  const _Home({required this.me});

  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final pairId = me.pairId!;

    return StreamBuilder<TidalMessage?>(
      stream: services.messages.inbox(pairId: pairId, myId: me.uid),
      builder: (context, waitingSnap) {
        return StreamBuilder<TidalMessage?>(
          stream: services.messages.currentlyOpen(pairId: pairId, myId: me.uid),
          builder: (context, openSnap) {
            final waiting = waitingSnap.data;
            final open = openSnap.data;
            final letter = open ?? waiting;

            final payload = WidgetPayload(
              state: open != null
                  ? LetterState.open
                  : waiting != null
                      ? LetterState.waiting
                      : LetterState.empty,
              messageId: letter?.id,
              text: letter?.text,
              openedAt: open?.openedAt,
              expiresAt: open?.expiresAt,
              partnerName: letter?.senderName,
              partnerCatId: letter?.senderCatId,
              idleLine: IdleChatter.random(),
              canSendAt: me.lastSentAt?.add(Config.sendCooldown),
            );

            return HomeScreen(
              myBreed: CatBreed.fromId(me.catId),
              myName: me.displayName,
              payload: payload,
              onChangeCat: () => _changeCat(context),
              onOpenJournal: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JournalScreen(
                    messages: services.messages.thread(pairId: pairId),
                    myId: me.uid,
                    myBreed: CatBreed.fromId(me.catId),
                    now: services.clock.now,
                  ),
                ),
              ),
              onCompose: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ComposeScreen(
                    partnerName: payload.partnerName ?? 'them',
                    canSendAt: payload.canSendAt,
                    onSend: (text) => _send(pairId, text),
                  ),
                ),
              ),
              onOpenLetter:
                  waiting == null ? null : () => _open(pairId, waiting),
            );
          },
        );
      },
    );
  }

  Future<String?> _send(String pairId, String text) async {
    // The pair doc is the only place that knows the recipient's uid.
    final pair = await services.pairing.pairRef(pairId).get();
    final members =
        List<String>.from(pair.data()?['memberIds'] as List? ?? const []);
    final other = members.where((m) => m != me.uid).toList();
    if (other.isEmpty) return 'They have not joined yet.';

    // Deliberately not awaited: commit() resolves only on server ack, so
    // awaiting would hang forever offline. The write hits the local cache
    // immediately and flushes when the connection returns.
    unawaited(services.messages
        .send(
          pairId: pairId,
          senderId: me.uid,
          recipientId: other.first,
          text: text,
          senderCatId: me.catId,
          senderName: me.displayName,
        )
        .catchError((_) {}));
    return null;
  }

  void _open(String pairId, TidalMessage letter) {
    // Already opened, or already gone — the stream reflects reality either way.
    unawaited(services.messages
        .open(pairId: pairId, messageId: letter.id)
        .catchError((_) {}));
  }

  void _changeCat(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CatSelectionScreen(
        initial: CatBreed.fromId(me.catId),
        onSelected: (b) async {
          await services.auth.saveProfile(
            uid: me.uid,
            displayName: me.displayName,
            catId: b.id,
          );
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    ));
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: CozyColors.sageGreen),
        ),
      );
}

class _Fatal extends StatelessWidget {
  const _Fatal({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🌊', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('Could not reach the tide',
                    style: CozyText.rounded(20, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('$error',
                    textAlign: TextAlign.center, style: CozyText.muted),
              ],
            ),
          ),
        ),
      );
}
