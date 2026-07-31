import 'package:cloud_firestore/cloud_firestore.dart';

/// One letter.
///
/// [openedAt] is the semantic flag: null means it is still waiting, whatever
/// [expiresAt] says. [expiresAt] is always populated because it is the Firestore
/// TTL field and TTL skips null values — an unopened letter carries a far-future
/// sentinel so abandoned docs still get collected.
class TidalMessage {
  const TidalMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.sentAt,
    required this.expiresAt,
    this.openedAt,
    this.senderCatId,
    this.senderName,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String text;

  /// Null while the serverTimestamp is still pending locally.
  final DateTime? sentAt;
  final DateTime? expiresAt;
  final DateTime? openedAt;
  final String? senderCatId;
  final String? senderName;

  bool get isOpened => openedAt != null;

  /// Client-side expiry. Never trust TTL for this: Firestore's deletion lags by
  /// up to 24h, so a doc can outlive its own expiry and must be filtered here.
  bool isVisibleAt(DateTime now) {
    if (!isOpened) return true; // waiting letters never expire from view
    return expiresAt == null || now.isBefore(expiresAt!);
  }

  static DateTime? _dt(dynamic v) => (v as Timestamp?)?.toDate();

  factory TidalMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return TidalMessage(
      id: doc.id,
      senderId: d['senderId'] as String? ?? '',
      recipientId: d['recipientId'] as String? ?? '',
      text: d['text'] as String? ?? '',
      sentAt: _dt(d['sentAt']),
      expiresAt: _dt(d['expiresAt']),
      openedAt: _dt(d['openedAt']),
      senderCatId: d['senderCatId'] as String?,
      senderName: d['senderName'] as String?,
    );
  }
}
