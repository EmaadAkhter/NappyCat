// Regression test for the bug that made "Create an invite" appear to do
// nothing.
//
// createInvite writes pairId to the user document immediately, so the code
// survives an app restart. Routing then treated "pairId is set" as "paired" and
// navigated straight past the pairing screen — the creator never saw their own
// code. Being paired means the pair document has TWO members, and that is what
// these assertions pin down.
//
// Runs against the emulator:
//   firebase emulators:start --project demo-tidal --config firebase.dev.json
//   flutter test integration_test/pairing_test.dart -d <udid> \
//     --dart-define=USE_EMULATOR=true --dart-define=TIDAL_ENV=dev

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;

import 'package:tidal/config.dart';
import 'package:tidal/firebase_options.dart';
import 'package:tidal/services/auth_service.dart';
import 'package:tidal/services/pairing_service.dart';

/// Must match the client's project, not a hardcoded guess. The Firestore
/// emulator namespaces data per project id, so seeding under a different one
/// writes to a database the app can never see — and every read silently comes
/// back empty.
final _project = DefaultFirebaseOptions.currentPlatform.projectId;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;
  late AuthService auth;
  late PairingService pairing;
  late String me;

  final base = 'http://${Config.emulatorHost}:${Config.firestoreEmulatorPort}';

  Future<void> clear() => http.delete(Uri.parse(
      '$base/emulator/v1/projects/$_project/databases/(default)/documents'));

  /// Second member joining, without needing a second signed-in session.
  Future<void> joinAs(String code, String uid) async {
    final r = await http.patch(
      Uri.parse('$base/v1/projects/$_project/databases/(default)/documents/pairs/$code'
          '?updateMask.fieldPaths=memberIds'),
      headers: {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'fields': {
          'memberIds': {
            'arrayValue': {
              'values': [
                {'stringValue': me},
                {'stringValue': uid},
              ]
            }
          }
        }
      }),
    );
    if (r.statusCode >= 300) throw StateError('join failed: ${r.body}');
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    db = FirebaseFirestore.instance;
    db.useFirestoreEmulator(Config.emulatorHost, Config.firestoreEmulatorPort);
    await FirebaseAuth.instance
        .useAuthEmulator(Config.emulatorHost, Config.authEmulatorPort);
    me = (await FirebaseAuth.instance.signInAnonymously()).user!.uid;
    auth = AuthService(FirebaseAuth.instance, db);
    pairing = PairingService(db);
  });

  // Seeded server-side rather than through saveProfile: clearing Firestore
  // behind the client's back leaves its cache stale, and pairId is write-once
  // so a user who has already made an invite can never legitimately make
  // another. Each test therefore starts from a genuinely fresh document.
  setUp(() async {
    await clear();

    // The emulator's clear-documents endpoint returns before the deletes have
    // all landed, so a document seeded immediately afterwards can be wiped out
    // from under the test. Seed, then confirm it is actually there.
    for (var attempt = 0; attempt < 20; attempt++) {
      final url =
          '$base/v1/projects/$_project/databases/(default)/documents/users/$me';
      await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer owner',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'fields': {
            'displayName': {'stringValue': 'Me'},
            'catId': {'stringValue': 'koala'},
            'createdAt': {'timestampValue': '2026-01-01T00:00:00Z'},
          }
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final check = await http.get(Uri.parse(url),
          headers: {'Authorization': 'Bearer owner'});
      if (check.statusCode == 200 && !check.body.contains('"pairId"')) return;
    }
    throw StateError('could not seed a clean profile for $me');
  });

  testWidgets('creating an invite yields a usable code', (_) async {
    final probe = await db.collection('users').doc(me)
        .get(const GetOptions(source: Source.server));
    expect(probe.exists, isTrue,
        reason: 'seed did not land for uid=$me; data=${probe.data()}');

    final code = await pairing.createInvite(me);
    expect(code, hasLength(PairingService.codeLength));
    expect(code, matches(RegExp(r'^[A-Z0-9]+$')));
    // Ambiguous glyphs are excluded so a code read aloud cannot become a
    // different valid code.
    expect(code, isNot(matches(RegExp(r'[ILOU01]'))));
  });

  testWidgets('a fresh invite has pairId set but is NOT yet paired', (_) async {
    final code = await pairing.createInvite(me);

    final profile = await auth.watch(me).firstWhere((u) => u?.pairId != null);
    expect(profile!.pairId, code,
        reason: 'pairId is written immediately so the code survives a restart');

    final members = await pairing.members(code).first;
    expect(members, [me]);
    expect(members.length < 2, isTrue,
        reason: 'THE BUG: routing on pairId alone skipped the pairing screen '
            'here, so the creator never saw their code');
  });

  testWidgets('the pair becomes complete only when someone joins', (_) async {
    final code = await pairing.createInvite(me);
    await joinAs(code, 'partner-uid');

    final complete = await pairing
        .members(code)
        .firstWhere((m) => m.length >= 2)
        .timeout(const Duration(seconds: 10));
    expect(complete, containsAll([me, 'partner-uid']));
  });

  testWidgets('the code is recoverable after a restart', (_) async {
    final code = await pairing.createInvite(me);

    // Simulates relaunching: all that survives is the user document.
    final reloaded = await auth.watch(me).firstWhere((u) => u?.pairId != null);
    expect(reloaded!.pairId, code,
        reason: 'without this the creator can never get their code back');
  });

  testWidgets('joining a full pair is refused with a readable message',
      (_) async {
    final code = await pairing.createInvite(me);
    await joinAs(code, 'partner-uid');

    await expectLater(
      pairing.join(uid: 'third-wheel', code: code),
      throwsA(isA<PairingError>()),
    );
  });

  testWidgets('someone who created an invite can switch to joining instead',
      (_) async {
    // The common mistake is both people tapping Create. Whoever went first must
    // be able to abandon their empty invite and enter the other's code —
    // pairId being write-once stranded them permanently.
    final mine = await pairing.createInvite(me);
    expect((await pairing.members(mine).first), [me]);

    await http.patch(
      Uri.parse('$base/v1/projects/$_project/databases/(default)/documents/pairs/THEIRS01'),
      headers: {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'fields': {
          'memberIds': {
            'arrayValue': {
              'values': [
                {'stringValue': 'partner-uid'}
              ]
            }
          },
          'createdAt': {'timestampValue': '2026-01-01T00:00:00Z'},
          'inviteExpiresAt': {'timestampValue': '2099-01-01T00:00:00Z'},
        }
      }),
    );

    await pairing.join(uid: me, code: 'THEIRS01');

    final switched =
        await auth.watch(me).firstWhere((u) => u?.pairId == 'THEIRS01');
    expect(switched!.pairId, 'THEIRS01');
  });

  testWidgets('an unknown code fails clearly rather than hanging', (_) async {
    await expectLater(
      pairing.join(uid: me, code: 'ZZZZZZZZ'),
      throwsA(isA<PairingError>()),
    );
  });
}
