// Smoke test against the REAL Firebase project, not the emulator.
//
// The emulator suite proves the logic. This proves the deployed reality: real
// anonymous auth, real deployed rules, real Firestore in asia-south1. It is
// deliberately tiny — it writes one profile document and deletes it again, so
// it leaves the project as it found it.
//
// Run WITHOUT --dart-define=USE_EMULATOR:
//   flutter test integration_test/live_smoke_test.dart -d <udid> \
//     --dart-define=TIDAL_ENV=dev

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tidal/config.dart';
import 'package:tidal/firebase_options.dart';
import 'package:tidal/services/auth_service.dart';
import 'package:tidal/services/clock.dart';
import 'package:tidal/services/pairing_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;
  late AuthService auth;
  late User me;

  setUpAll(() async {
    expect(Config.useEmulator, isFalse,
        reason: 'this suite must hit the real project');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    db = FirebaseFirestore.instance;
    auth = AuthService(FirebaseAuth.instance, db);
    me = await auth.signIn();
  });

  tearDownAll(() async {
    // Leave nothing behind. Rules permit self-delete.
    try {
      await db.collection('users').doc(me.uid).delete();
    } catch (_) {}
    await FirebaseAuth.instance.currentUser?.delete();
  });

  testWidgets('anonymous sign-in works against the live project', (_) async {
    expect(me.uid, isNotEmpty);
    expect(me.isAnonymous, isTrue);
    expect(DefaultFirebaseOptions.currentPlatform.projectId, 'napcat-2e042');
  });

  testWidgets('the deployed rules accept a real profile write', (_) async {
    await auth.saveProfile(uid: me.uid, displayName: 'Smoke', catId: 'koala');

    final snap = await db
        .collection('users')
        .doc(me.uid)
        .get(const GetOptions(source: Source.server));
    expect(snap.exists, isTrue);
    expect(snap.data()!['displayName'], 'Smoke');
    expect(snap.data()!['catId'], 'koala');
  });

  testWidgets('the deployed rules still reject reading someone else', (_) async {
    await expectLater(
      db.collection('users').doc('not-me').get(const GetOptions(source: Source.server)),
      throwsA(isA<FirebaseException>()),
      reason: 'a live misconfiguration would show up here first',
    );
  });

  testWidgets('the clock syncs against real server time', (_) async {
    await auth.saveProfile(uid: me.uid, displayName: 'Smoke', catId: 'koala');
    final clock = Clock(db);
    await clock.sync(me.uid);
    expect(clock.isSynced, isTrue,
        reason: 'countdowns depend on this; silent failure means drift');
    expect(clock.offset.abs(), lessThan(const Duration(minutes: 5)));
  });

  testWidgets('pairing creates a real invite the rules accept', (_) async {
    await auth.saveProfile(uid: me.uid, displayName: 'Smoke', catId: 'koala');
    final pairing = PairingService(db);
    final code = await pairing.createInvite(me.uid);

    expect(code, hasLength(PairingService.codeLength));
    final pair = await pairing
        .pairRef(code)
        .get(const GetOptions(source: Source.server));
    expect(pair.exists, isTrue);
    expect(List<String>.from(pair.data()!['memberIds'] as List), [me.uid]);

    // Codes must not be enumerable, or invites are guessable in bulk.
    await expectLater(
      db.collection('pairs').get(const GetOptions(source: Source.server)),
      throwsA(isA<FirebaseException>()),
    );
  });
}
