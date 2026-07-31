// End-to-end test of the real Dart services against the Firestore emulator,
// enforcing the real security rules.
//
// The JS suite (test/rules.test.mjs) proves the RULES are correct. This proves
// the CLIENT agrees with them — that MessageService actually emits the batch and
// the exact field shapes the rules demand. That gap is the likeliest place for a
// silent break, since a forgotten batch fails closed with an opaque
// permission-denied at runtime rather than at compile time.
//
// Run:
//   firebase emulators:start --project demo-tidal --config firebase.dev.json
//   flutter test integration_test/messaging_test.dart -d <simulator-udid> \
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
import 'package:tidal/services/clock.dart';
import 'package:tidal/services/message_service.dart';

const _project = 'demo-tidal';
final _base = 'http://${Config.emulatorHost}:${Config.firestoreEmulatorPort}';
final _docs =
    '$_base/v1/projects/$_project/databases/(default)/documents';

/// Writes bypassing the security rules, so the test can set up a second user
/// it has no credentials for.
Future<void> _seed(String path, Map<String, dynamic> fields) async {
  final r = await http.patch(
    Uri.parse('$_docs/$path'),
    headers: {'Authorization': 'Bearer owner', 'Content-Type': 'application/json'},
    body: jsonEncode({'fields': fields}),
  );
  if (r.statusCode >= 300) {
    throw StateError('seed $path failed: ${r.statusCode} ${r.body}');
  }
}

Map<String, dynamic> _str(String v) => {'stringValue': v};
Map<String, dynamic> _ts(DateTime v) =>
    {'timestampValue': v.toUtc().toIso8601String()};

Future<void> _clearFirestore() async {
  await http.delete(Uri.parse(
      '$_base/emulator/v1/projects/$_project/databases/(default)/documents'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore db;
  late MessageService messages;
  late String meUid;
  const themUid = 'partner-uid';
  const pairId = 'TESTPAIR1';

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    db = FirebaseFirestore.instance;
    db.useFirestoreEmulator(Config.emulatorHost, Config.firestoreEmulatorPort);
    await FirebaseAuth.instance
        .useAuthEmulator(Config.emulatorHost, Config.authEmulatorPort);

    final cred = await FirebaseAuth.instance.signInAnonymously();
    meUid = cred.user!.uid;
    messages = MessageService(db, Clock(db));
  });

  setUp(() async {
    await _clearFirestore();
    await _seed('users/$meUid', {
      'displayName': _str('Me'),
      'catId': _str('koala'),
      'createdAt': _ts(DateTime.now()),
    });
    await _seed('users/$themUid', {
      'displayName': _str('Them'),
      'catId': _str('tabby'),
      'createdAt': _ts(DateTime.now()),
    });
    await _seed('pairs/$pairId', {
      'memberIds': {
        'arrayValue': {
          'values': [_str(meUid), _str(themUid)]
        }
      },
      'createdAt': _ts(DateTime.now()),
      'inviteExpiresAt': _ts(DateTime.now().add(const Duration(hours: 12))),
    });
  });

  Future<void> send([String text = 'the sea was flat today']) => messages.send(
        pairId: pairId,
        senderId: meUid,
        recipientId: themUid,
        text: text,
        senderCatId: 'koala',
        senderName: 'Me',
      );

  /// Puts an unopened letter from them to me, bypassing rules.
  Future<String> incoming() async {
    final id = 'letter-${DateTime.now().microsecondsSinceEpoch}';
    await _seed('pairs/$pairId/messages/$id', {
      'senderId': _str(themUid),
      'recipientId': _str(meUid),
      'text': _str('thinking of you from the engine room'),
      'sentAt': _ts(DateTime.now()),
      'openedAt': {'nullValue': null},
      'expiresAt': _ts(DateTime.now().add(const Duration(hours: 24))),
      'senderCatId': _str('tabby'),
      'senderName': _str('Them'),
    });
    return id;
  }

  group('send', () {
    testWidgets('a well-formed letter is accepted by the real rules',
        (_) async {
      await send();
      final snap = await db
          .collection('pairs/$pairId/messages')
          .get(const GetOptions(source: Source.server));
      expect(snap.docs, hasLength(1));

      final d = snap.docs.first.data();
      expect(d['senderId'], meUid);
      expect(d['recipientId'], themUid);
      // Must be present AND null: the inbox query filters on it, and Firestore
      // does not index documents that omit the field.
      expect(d.containsKey('openedAt'), isTrue);
      expect(d['openedAt'], isNull);
      expect(d['sentAt'], isA<Timestamp>());
      expect(d['expiresAt'], isA<Timestamp>());
    });

    testWidgets('the rate limit blocks a second letter in the window',
        (_) async {
      await send('first');
      await expectLater(send('second'), throwsA(isA<FirebaseException>()));

      final snap = await db
          .collection('pairs/$pairId/messages')
          .get(const GetOptions(source: Source.server));
      expect(snap.docs, hasLength(1), reason: 'second letter must not exist');
    });

    testWidgets('a letter without the batched stamp is rejected', (_) async {
      // Exactly the bypass the getAfter() rule exists to close: write the
      // message alone, never stamping users/{uid}.lastSentAt.
      final naked = db.collection('pairs/$pairId/messages').doc();
      await expectLater(
        naked.set({
          'senderId': meUid,
          'recipientId': themUid,
          'text': 'sneaking past the rate limit',
          'sentAt': FieldValue.serverTimestamp(),
          'openedAt': null,
          'expiresAt': Timestamp.fromDate(
              DateTime.now().add(Config.unopenedTtl)),
          'senderCatId': 'koala',
          'senderName': 'Me',
        }),
        throwsA(isA<FirebaseException>()),
      );
    });

    testWidgets('over-long text is refused before it reaches the network',
        (_) async {
      expect(
        () => send('x' * (MessageService.maxLength + 1)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('open', () {
    testWidgets('opening starts the clock and sets expiry to openedAt + ttl',
        (_) async {
      final id = await incoming();
      final at = DateTime.now();
      await messages.open(pairId: pairId, messageId: id, openedAt: at);

      final d = (await db
              .doc('pairs/$pairId/messages/$id')
              .get(const GetOptions(source: Source.server)))
          .data()!;
      final opened = (d['openedAt'] as Timestamp).toDate();
      final expires = (d['expiresAt'] as Timestamp).toDate();

      expect(opened.difference(at).inSeconds.abs(), lessThan(2));
      expect(
        expires.difference(opened) - Config.openTtl,
        lessThan(const Duration(seconds: 2)),
        reason: 'rules enforce expiresAt == openedAt + openTtl exactly',
      );
    });

    testWidgets('a letter cannot be re-opened to restart its clock', (_) async {
      final id = await incoming();
      await messages.open(pairId: pairId, messageId: id);
      await expectLater(
        messages.open(pairId: pairId, messageId: id),
        throwsA(isA<FirebaseException>()),
      );
    });

    testWidgets('the sender cannot open their own letter', (_) async {
      await send();
      final mine = (await db
              .collection('pairs/$pairId/messages')
              .get(const GetOptions(source: Source.server)))
          .docs
          .first;
      await expectLater(
        messages.open(pairId: pairId, messageId: mine.id),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('queries', () {
    testWidgets('inbox surfaces only the unopened letter addressed to me',
        (_) async {
      final id = await incoming();
      final waiting = await messages
          .inbox(pairId: pairId, myId: meUid)
          .firstWhere((m) => m != null);
      expect(waiting!.id, id);
      expect(waiting.isOpened, isFalse);

      await messages.open(pairId: pairId, messageId: id);

      // A fresh listener's first emission can come from the local cache, so
      // assert the stream SETTLES on empty rather than trusting one frame.
      final cleared = await messages
          .inbox(pairId: pairId, myId: meUid)
          .firstWhere((m) => m == null)
          .timeout(const Duration(seconds: 10));
      expect(cleared, isNull, reason: 'opened letters leave the inbox');
    });

    testWidgets('the journal hides letters past their expiry', (_) async {
      final id = await incoming();
      // Backdate so the open window has already elapsed. Client-side filtering
      // is the real mechanism — Firestore TTL lags by up to 24h.
      final past = DateTime.now().subtract(const Duration(days: 1));
      await _seed('pairs/$pairId/messages/$id', {
        'senderId': _str(themUid),
        'recipientId': _str(meUid),
        'text': _str('this one has faded'),
        'sentAt': _ts(past),
        'openedAt': _ts(past),
        'expiresAt': _ts(past.add(const Duration(minutes: 1))),
        'senderCatId': _str('tabby'),
        'senderName': _str('Them'),
      });

      final visible = await messages.thread(pairId: pairId).first;
      expect(visible.where((m) => m.id == id), isEmpty,
          reason: 'expired letters must not render even while the doc exists');

      final raw = await db
          .collection('pairs/$pairId/messages')
          .get(const GetOptions(source: Source.server));
      expect(raw.docs.where((d) => d.id == id), isNotEmpty,
          reason: 'the doc is still there; only the client filters it');
    });
  });
}
