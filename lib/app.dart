import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/cat_breed.dart';
import 'models/widget_payload.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/cat_naming_screen.dart';
import 'screens/onboarding/cat_selection_screen.dart';
import 'screens/onboarding/widget_guide_screen.dart';
import 'services/idle_chatter.dart';
import 'theme/cozy_theme.dart';

enum _Step { selectCat, nameCat, widgetGuide, home }

/// Phase 1 shell: the real navigation flow, driven by local state.
///
/// Firebase replaces the local fields in Phase 2 — the screens themselves take
/// their data as parameters precisely so that swap touches only this file.
class TidalApp extends StatefulWidget {
  const TidalApp({super.key});

  @override
  State<TidalApp> createState() => _TidalAppState();
}

class _TidalAppState extends State<TidalApp> {
  _Step _step = _Step.selectCat;
  CatBreed _myBreed = CatBreed.tabby;
  String _myName = '';

  // Stand-in for the synced Firestore state until Phase 2.
  WidgetPayload _payload = WidgetPayload(
    state: LetterState.empty,
    partnerName: 'Sim',
    partnerCatId: CatBreed.koala.id,
    idleLine: IdleChatter.random(),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tidal',
      debugShowCheckedModeBanner: false,
      theme: buildCozyTheme(),
      darkTheme: buildCozyTheme(),
      themeMode: ThemeMode.light,
      home: switch (_step) {
        _Step.selectCat => CatSelectionScreen(
            initial: _myBreed,
            onSelected: (b) => setState(() {
              _myBreed = b;
              _step = _Step.nameCat;
            }),
          ),
        _Step.nameCat => CatNamingScreen(
            breed: _myBreed,
            initialName: _myName,
            onConfirmed: (name) => setState(() {
              _myName = name;
              _step = _Step.widgetGuide;
            }),
          ),
        _Step.widgetGuide => WidgetGuideScreen(
            breed: _myBreed,
            onFinish: () => setState(() => _step = _Step.home),
          ),
        _Step.home => HomeScreen(
            myBreed: _myBreed,
            myName: _myName,
            payload: _payload,
            onChangeCat: () => setState(() => _step = _Step.selectCat),
            onCompose: _fakeSend,
            onOpenLetter: _fakeOpen,
          ),
      },
    );
  }

  // --- Phase 1 stand-ins. Replaced by MessageService in Phase 2. ---

  void _fakeSend() {
    final now = DateTime.now();
    setState(() {
      _payload = _payload.copyWith(canSendAt: now.add(const Duration(minutes: 2)));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Letter sent (local stub — Firebase lands in Phase 2)')),
    );
    // Simulate their reply arriving so the four states are all reachable.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _payload = _payload.copyWith(
            state: LetterState.waiting,
            messageId: 'stub-1',
            text: 'the sea was flat today and I thought of you',
          ));
    });
  }

  void _fakeOpen() {
    if (_payload.state != LetterState.waiting) return;
    final now = DateTime.now();
    setState(() => _payload = _payload.copyWith(
          state: LetterState.open,
          openedAt: now,
          expiresAt: now.add(const Duration(minutes: 2)),
        ));
  }
}
