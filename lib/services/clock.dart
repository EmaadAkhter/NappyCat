import 'package:cloud_firestore/cloud_firestore.dart';

/// Server-corrected wall clock.
///
/// Every countdown in this app ("fades in 4h 12m", "next letter in 5h") is
/// computed against timestamps the SERVER wrote. If the device clock is off by
/// ten minutes the countdowns lie, and letters appear to vanish early or linger
/// past their time. So measure the offset once at launch and apply it
/// everywhere via [now].
///
/// Probes through the user's own doc rather than a scratch collection, so it
/// needs no extra rules surface.
class Clock {
  Clock(this._db);

  final FirebaseFirestore _db;
  Duration _offset = Duration.zero;
  bool _synced = false;

  /// Best-effort: on failure the offset stays zero, which is exactly the
  /// behaviour of not having this at all. Never throws.
  Future<void> sync(String uid) async {
    try {
      final ref = _db.collection('users').doc(uid);
      final before = DateTime.now();
      await ref.update({'lastSeenAt': FieldValue.serverTimestamp()});
      final snap = await ref.get(const GetOptions(source: Source.server));
      final after = DateTime.now();

      final server = (snap.data()?['lastSeenAt'] as Timestamp?)?.toDate();
      if (server == null) return;

      // Midpoint of the round trip is the best estimate of local time at the
      // instant the server stamped it.
      final localMid = before.add((after.difference(before)) ~/ 2);
      _offset = server.difference(localMid);
      _synced = true;
    } catch (_) {
      // Offline, or the doc does not exist yet. Fall back to the device clock.
    }
  }

  bool get isSynced => _synced;
  Duration get offset => _offset;

  DateTime now() => DateTime.now().add(_offset);
}
