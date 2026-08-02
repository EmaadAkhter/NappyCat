import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pairing by invite code, where the code IS the pair document ID.
///
/// That is what lets a joiner `get()` the doc directly with no query and no
/// Cloud Function. Rules forbid `list` on the collection, so codes cannot be
/// enumerated — but they are guessable by brute force, hence the short expiry
/// and the fact that a pair accepts exactly one joiner.
class PairingService {
  PairingService(this._db);

  final FirebaseFirestore _db;

  /// Crockford-ish: no I/L/O/U/0/1 so a code read aloud or typed from a
  /// screenshot cannot be mistyped into a different valid code.
  static const _alphabet = 'ABCDEFGHJKMNPQRSTVWXYZ23456789';
  static const codeLength = 8;
  static const inviteLifetime = Duration(hours: 12);

  final _rng = Random.secure();

  String _newCode() =>
      List.generate(codeLength, (_) => _alphabet[_rng.nextInt(_alphabet.length)])
          .join();

  DocumentReference<Map<String, dynamic>> pairRef(String code) =>
      _db.collection('pairs').doc(code);

  /// Creates an invite and returns its code. Retries on the astronomically
  /// unlikely collision, where create fails because the doc already exists.
  Future<String> createInvite(String uid) async {
    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _newCode();
      try {
        await pairRef(code).set({
          'memberIds': [uid],
          'createdAt': FieldValue.serverTimestamp(),
          'inviteExpiresAt': Timestamp.fromDate(DateTime.now().add(inviteLifetime)),
        });
        await _db.collection('users').doc(uid).update({'pairId': code});
        return code;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        // A collision retries on a new code. But permission-denied also covers
        // every rules rejection, so keep the cause — swallowing it is what made
        // this failure impossible to diagnose from the UI.
        lastError = e;
      }
    }
    throw StateError('could not allocate an invite code: $lastError');
  }

  /// Joins an existing invite. Throws [PairingError] with something a human can
  /// read, because every one of these cases is reachable by normal mistyping.
  Future<String> join({required String uid, required String code}) async {
    final normalized = code.trim().toUpperCase();
    final ref = pairRef(normalized);

    final DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await ref.get();
    } on FirebaseException {
      throw const PairingError('That code does not look right.');
    }

    if (!snap.exists) throw const PairingError('No invite with that code.');

    final data = snap.data()!;
    final members = List<String>.from(data['memberIds'] as List? ?? const []);
    if (members.contains(uid)) return normalized; // already joined, idempotent
    if (members.length >= 2) throw const PairingError('That pair is already full.');

    final expires = (data['inviteExpiresAt'] as Timestamp?)?.toDate();
    if (expires != null && DateTime.now().isAfter(expires)) {
      throw const PairingError('That invite has expired.');
    }

    try {
      await ref.update({'memberIds': [...members, uid]});
    } on FirebaseException {
      throw const PairingError('Could not join — the invite may have just been used.');
    }
    await _db.collection('users').doc(uid).update({'pairId': normalized});
    return normalized;
  }

  /// Disconnect: remove myself from the pair, then drop my pointer to it.
  /// The pair doc survives for the other person (their letters keep fading on
  /// schedule); their side shows the pairing screen again and they can
  /// disconnect too. Removing membership first matters — it is what revokes
  /// my read access under the rules.
  Future<void> leave({required String uid, required String pairId}) async {
    try {
      await pairRef(pairId).update({
        'memberIds': FieldValue.arrayRemove([uid]),
      });
    } on FirebaseException {
      // Already removed, or the pair is gone: clearing the pointer is what
      // actually un-pairs this device, so carry on.
    }
    // One write, both fields: the rules only allow wiping the send stamp
    // together with the pointer, after membership is already gone — a new
    // pairing starts with a fresh timer.
    await _db.collection('users').doc(uid).update({
      'pairId': FieldValue.delete(),
      'lastSentAt': FieldValue.delete(),
    });
  }

  /// Live view of the pair, so the "waiting for them" screen advances by itself
  /// the moment the other person joins.
  Stream<List<String>> members(String code) =>
      pairRef(code).snapshots().map((s) =>
          List<String>.from(s.data()?['memberIds'] as List? ?? const []));
}

class PairingError implements Exception {
  const PairingError(this.message);
  final String message;
  @override
  String toString() => message;
}
