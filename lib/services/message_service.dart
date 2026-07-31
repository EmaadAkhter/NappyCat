import 'package:cloud_firestore/cloud_firestore.dart';
import '../config.dart';
import '../models/tidal_message.dart';
import 'clock.dart';

/// The ONLY code path that writes messages.
///
/// [send] must always use a WriteBatch: the security rule uses getAfter() to
/// require that the message create and the users/{uid}.lastSentAt stamp land in
/// the same atomic commit. A send that forgets the batch fails closed with an
/// opaque permission error, which is exactly why this lives in one place.
class MessageService {
  MessageService(this._db, this._clock);

  final FirebaseFirestore _db;
  final Clock _clock;

  static const maxLength = 280;

  CollectionReference<Map<String, dynamic>> _messages(String pairId) =>
      _db.collection('pairs').doc(pairId).collection('messages');

  /// Fire-and-forget by design. The returned future resolves only on server
  /// ack, so awaiting it hangs forever offline — but the write applies to the
  /// local cache immediately and persists to disk, surviving app kill. Drive UI
  /// off the snapshot, not off this future.
  Future<void> send({
    required String pairId,
    required String senderId,
    required String recipientId,
    required String text,
    required String senderCatId,
    required String senderName,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('empty letter');
    }
    if (trimmed.length > maxLength) {
      throw ArgumentError('letter exceeds $maxLength characters');
    }

    final batch = _db.batch();
    batch.set(_messages(pairId).doc(), {
      'senderId': senderId,
      'recipientId': recipientId,
      'text': trimmed,
      'sentAt': FieldValue.serverTimestamp(),
      // Literal null, not omitted: the inbox query filters on openedAt == null,
      // and Firestore does not index documents that omit the field.
      'openedAt': null,
      'expiresAt': Timestamp.fromDate(_clock.now().add(Config.unopenedTtl)),
      'senderCatId': senderCatId,
      'senderName': senderName,
    });
    batch.update(_db.collection('users').doc(senderId), {
      'lastSentAt': FieldValue.serverTimestamp(),
    });
    return batch.commit();
  }

  /// Starts the expiry clock. [openedAt] comes from wherever the tap happened —
  /// notably the native widget, which may have registered the open while
  /// offline — so that local and server agree on the same instant.
  ///
  /// The rules enforce expiresAt == openedAt + openTtl, so both are computed
  /// here rather than trusting a server timestamp that reads as null locally.
  Future<void> open({
    required String pairId,
    required String messageId,
    DateTime? openedAt,
  }) {
    final at = openedAt ?? _clock.now();
    return _messages(pairId).doc(messageId).update({
      'openedAt': Timestamp.fromDate(at),
      'expiresAt': Timestamp.fromDate(at.add(Config.openTtl)),
    });
  }

  /// The single unopened letter addressed to me, if any.
  ///
  /// Must be `isNull: true`, NOT `isEqualTo: null`. Every where() parameter
  /// defaults to null, so `isEqualTo: null` is indistinguishable from "argument
  /// not supplied" and the filter is silently dropped — the query then returns
  /// opened letters too, with no error anywhere.
  Stream<TidalMessage?> inbox({required String pairId, required String myId}) =>
      _messages(pairId)
          .where('recipientId', isEqualTo: myId)
          .where('openedAt', isNull: true)
          .orderBy('sentAt', descending: true)
          .limit(1)
          .snapshots()
          .map((s) => s.docs.isEmpty ? null : TidalMessage.fromDoc(s.docs.first));

  /// Everything still alive, both directions, newest first.
  ///
  /// There is no archive and nothing to purge — the journal is simply this
  /// query with client-side expiry applied, which is what makes "ephemeral"
  /// fall out for free.
  Stream<List<TidalMessage>> thread({required String pairId}) => _messages(pairId)
      .orderBy('sentAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) {
        final now = _clock.now();
        return s.docs
            .map(TidalMessage.fromDoc)
            .where((m) => m.isVisibleAt(now))
            .toList();
      });

  /// The most recently opened letter still within its window — what the cat is
  /// currently speaking.
  Stream<TidalMessage?> currentlyOpen({
    required String pairId,
    required String myId,
  }) =>
      _messages(pairId)
          .where('recipientId', isEqualTo: myId)
          .orderBy('sentAt', descending: true)
          .limit(10)
          .snapshots()
          .map((s) {
            final now = _clock.now();
            for (final doc in s.docs) {
              final m = TidalMessage.fromDoc(doc);
              if (m.isOpened && m.isVisibleAt(now)) return m;
            }
            return null;
          });
}
