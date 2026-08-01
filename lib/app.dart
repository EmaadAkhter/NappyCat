import 'dart:async';
import 'dart:convert';
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
import 'services/widget_bridge.dart';
import 'theme/cozy_colors.dart';
import 'theme/cozy_text.dart';
import 'theme/cozy_theme.dart';

class TidalApp extends StatelessWidget {
  const TidalApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      title: 'NappyCat',
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
      _showedGuide = await GuideFlag.wasShown();
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
          return PairingScreen(uid: _uid!, pairing: services.pairing);
        }

        // Having a pairId is NOT the same as being paired: creating an invite
        // sets it immediately so the code survives an app restart, but the
        // other person has not joined yet. Routing on pairId alone navigated
        // straight past the pairing screen, so the creator never saw their own
        // code. Wait for the pair to actually have two members.
        return StreamBuilder<List<String>>(
          stream: services.pairing.members(me.pairId!),
          builder: (context, pairSnap) {
            if (!pairSnap.hasData) return const _Loading();
            if (pairSnap.data!.length < 2) {
              return PairingScreen(
                uid: _uid!,
                pairing: services.pairing,
                resumeCode: me.pairId,
              );
            }

            if (!_showedGuide) {
              return WidgetGuideScreen(
                breed: CatBreed.fromId(me.catId),
                onFinish: () {
                  // Persisted: this screen is a one-time tour, not a toll booth
                  // on every launch.
                  GuideFlag.markShown();
                  setState(() => _showedGuide = true);
                },
              );
            }

            final partnerId =
                pairSnap.data!.firstWhere((m) => m != _uid, orElse: () => '');
            return _Home(me: me, partnerId: partnerId);
          },
        );
      },
    );
  }
}

/// Home, driven by the two live queries and composed into the same
/// [WidgetPayload] the native widgets will read — so the in-app hero card and
/// the home-screen widget can never disagree about what the cat is doing.
class _Home extends StatefulWidget {
  const _Home({required this.me, required this.partnerId});

  final AppUser me;
  final String partnerId;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with WidgetsBindingObserver {
  AppUser get me => widget.me;

  /// Publishing on every rebuild would hammer the App Group and the widget
  /// reload budget, so only publish when the blob actually changes.
  String? _lastPublished;

  /// Chosen once per session, not per rebuild. A fresh random line every build
  /// would make every payload look different and defeat the dedup above.
  final String _idleLine = IdleChatter.random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reconcile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The widget tap launches the app, so resume is when the breadcrumb is
    // waiting. Cold start is covered by initState.
    if (state == AppLifecycleState.resumed) _reconcile();
  }

  /// Flushes a widget tap to Firestore. The open is fire-and-forget through the
  /// SDK: offline it persists to the on-disk mutation queue and lands on the
  /// next connection, even if the app is killed in between.
  Future<void> _reconcile() async {
    final pending = await WidgetBridge.takePendingOpen();
    if (pending == null) return;
    await WidgetBridge.clearPendingOpen();

    try {
      await services.messages.open(
        pairId: me.pairId!,
        messageId: pending.messageId,
        openedAt: pending.tappedAt,
      );
    } catch (_) {
      // Already opened, or already gone. The widget has shown it either way,
      // and the stream is the source of truth from here.
    }
  }

  void _publish(WidgetPayload payload) {
    final encoded = jsonEncode(payload.toJson());
    if (encoded == _lastPublished) return;
    _lastPublished = encoded;
    WidgetBridge.publish(payload);
  }

  /// Set the instant the user taps Read, before the server write lands. The
  /// stream catches up within a second or two, but without this the tap
  /// produced no visible change until then — which read as "the button doesn't
  /// work unless you hold it".
  TidalMessage? _justOpened;
  DateTime? _justOpenedAt;

  @override
  Widget build(BuildContext context) {
    final pairId = me.pairId!;

    return StreamBuilder<AppUser?>(
      // The partner's real profile. Before this, their name and cat were known
      // only from letter denormalization — so with no letter in flight the app
      // fell back to the grey tabby, every time, no matter what anyone chose.
      stream: widget.partnerId.isEmpty
          ? const Stream.empty()
          : services.auth.watch(widget.partnerId),
      builder: (context, partnerSnap) {
        final partner = partnerSnap.data;

        return StreamBuilder<TidalMessage?>(
          stream: services.messages.inbox(pairId: pairId, myId: me.uid),
          builder: (context, waitingSnap) {
            return StreamBuilder<TidalMessage?>(
              stream:
                  services.messages.currentlyOpen(pairId: pairId, myId: me.uid),
              builder: (context, openSnap) {
                final waiting = waitingSnap.data;
                var open = openSnap.data;

                // Optimistic open: trust the local tap until the server
                // catches up, then drop it.
                if (open != null && open.id == _justOpened?.id) {
                  _justOpened = null;
                  _justOpenedAt = null;
                }
                final justOpened = _justOpened;
                if (open == null && justOpened != null) {
                  open = TidalMessage(
                    id: justOpened.id,
                    senderId: justOpened.senderId,
                    recipientId: justOpened.recipientId,
                    text: justOpened.text,
                    sentAt: justOpened.sentAt,
                    openedAt: _justOpenedAt,
                    expiresAt: _justOpenedAt!.add(Config.openTtl),
                    senderCatId: justOpened.senderCatId,
                    senderName: justOpened.senderName,
                  );
                }

                final letter = open ??
                    (waiting?.id == justOpened?.id ? null : waiting);

                // A stream error must never masquerade as an empty state:
                // that is exactly how the missing currentlyOpen index read as
                // "the letter vanished" while the server had accepted the open.
                if (openSnap.hasError) {
                  debugPrint('currentlyOpen stream error: ${openSnap.error}');
                }
                if (waitingSnap.hasError) {
                  debugPrint('inbox stream error: ${waitingSnap.error}');
                }
                final payload = WidgetPayload(
                  state: open != null
                      ? LetterState.open
                      : letter != null
                          ? LetterState.waiting
                          : LetterState.empty,
                  messageId: (open ?? letter)?.id,
                  text: (open ?? letter)?.text,
                  openedAt: open?.openedAt,
                  expiresAt: open?.expiresAt,
                  partnerName:
                      partner?.displayName ?? (open ?? letter)?.senderName,
                  partnerCatId:
                      partner?.catId ?? (open ?? letter)?.senderCatId,
                  idleLine: _idleLine,
                  canSendAt: me.lastSentAt?.add(Config.sendCooldown),
                );

                // One derivation, one writer — the widget and this screen
                // render from the identical payload, so they cannot disagree.
                _publish(payload);

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
                  onOpenLetter: waiting == null || open != null
                      ? null
                      : () {
                          setState(() {
                            _justOpened = waiting;
                            _justOpenedAt = services.clock.now();
                          });
                          _open(pairId, waiting);
                        },
                );
              },
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
                Text('Couldn\'t wake the cat',
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
