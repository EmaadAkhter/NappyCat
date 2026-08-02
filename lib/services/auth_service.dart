import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

import 'desktop_session.dart';

/// Anonymous auth for now.
///
/// Two known people on two known phones do not need an account system. When
/// real sign-in arrives it must use linkWithCredential so the existing UID —
/// and therefore the pair and every letter in it — survives the upgrade.
class AuthService {
  AuthService(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get current => _auth.currentUser;
  Stream<User?> get changes => _auth.authStateChanges();

  Future<User> signIn() async {
    final desktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
    if (desktop) return DesktopSession.ensureSignedIn(_auth);
    return _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
  }

  DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _db.collection('users').doc(uid);

  Stream<AppUser?> watch(String uid) =>
      userRef(uid).snapshots().map((s) => s.exists ? AppUser.fromDoc(s) : null);

  /// Creates the profile on first run, updates it thereafter. Split because the
  /// rules deliberately allow different key sets for create and update, so a
  /// single merged write cannot satisfy both.
  ///
  /// The existence check MUST come from the server. A cached `get` can report a
  /// document that no longer exists, which sends this down the update path; the
  /// update then applies locally, resolves as if it worked, and the profile is
  /// never actually created. Everything downstream that needs the user document
  /// — pairing especially — then fails with an opaque permission error.
  Future<void> saveProfile({
    required String uid,
    required String displayName,
    required String catId,
  }) async {
    final ref = userRef(uid);

    bool exists;
    try {
      exists = (await ref.get(const GetOptions(source: Source.server))).exists;
    } on FirebaseException {
      // Offline. Fall back to the cache — wrong only in the rare case above,
      // and better than refusing to save at all.
      exists = (await ref.get()).exists;
    }

    if (exists) {
      await ref.update({'displayName': displayName, 'catId': catId});
    } else {
      await ref.set({
        'displayName': displayName,
        'catId': catId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.catId,
    this.pairId,
    this.lastSentAt,
  });

  final String uid;
  final String displayName;
  final String catId;
  final String? pairId;
  final DateTime? lastSentAt;

  bool get isPaired => pairId != null;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? '',
      catId: d['catId'] as String? ?? 'tabby',
      pairId: d['pairId'] as String?,
      lastSentAt: (d['lastSentAt'] as Timestamp?)?.toDate(),
    );
  }
}
