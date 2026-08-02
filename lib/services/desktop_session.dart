import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

/// Desktop identity without the keychain.
///
/// macOS refuses keychain persistence to unsigned apps (firebase_auth threw
/// keychain-error on other people's Macs, and every relaunch minted a fresh
/// anonymous account — which silently destroys the pairing). Windows' beta
/// SDK is no sturdier. So on desktop the app creates ONE email/password
/// account with random credentials, keeps them in a local file, and signs in
/// with them on every launch: same uid forever, no Apple entitlements
/// involved.
///
/// The password only ever guards this auto-generated account; it never
/// belonged to the user and unlocks nothing else of theirs.
class DesktopSession {
  const DesktopSession._();

  /// Auth errors that mean the STORED ACCOUNT is dead — only these justify
  /// abandoning the session file and starting a fresh identity. Anything else
  /// (network down, keychain weirdness, SDK bugs) must surface, not silently
  /// orphan the pairing by minting yet another account.
  static const _accountGone = {
    'user-not-found',
    'user-disabled',
    'invalid-credential',
    'INVALID_LOGIN_CREDENTIALS',
    'wrong-password',
    'invalid-email',
  };

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}session.json');
  }

  static String _random(int bytes) {
    final r = Random.secure();
    return List.generate(bytes, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static Future<User> ensureSignedIn(FirebaseAuth auth) async {
    final existing = auth.currentUser;
    if (existing != null) return existing;

    final f = await _file();
    if (await f.exists()) {
      Map<String, dynamic>? j;
      try {
        j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        j = null; // corrupt file: the only other reason to start over
      }
      if (j != null) {
        try {
          return await _authed(
            auth,
            () => auth.signInWithEmailAndPassword(
              email: j!['email'] as String,
              password: j['password'] as String,
            ),
          );
        } on FirebaseAuthException catch (e) {
          // ignore: avoid_print
          print('NAPPYDESK stored sign-in failed: ${e.code} ${e.message}');
          if (!_accountGone.contains(e.code)) rethrow;
        }
      }
      await f.delete();
    }

    final email = '${_random(12)}@desktop.nappycat.app';
    final password = _random(24);

    // Write the credentials BEFORE creating the account, and create the parent
    // directory first — path_provider does not. The original order signed up
    // and then failed the write, minting a fresh orphan identity per launch,
    // which is precisely the disease this class exists to cure.
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode({'email': email, 'password': password}));

    return _authed(
      auth,
      () => auth.createUserWithEmailAndPassword(email: email, password: password),
    );
  }

  /// Runs an auth call tolerating the unsigned-macOS failure mode: the server
  /// side succeeds, then the SDK throws while saving the session to a keychain
  /// it cannot use. The session file IS our persistence, so signed-in-but-not-
  /// saved is a success here, not an error.
  static Future<User> _authed(
    FirebaseAuth auth,
    Future<UserCredential> Function() call,
  ) async {
    try {
      final u = (await call()).user;
      if (u != null) return u;
    } on FirebaseAuthException catch (e) {
      final u = auth.currentUser;
      // ignore: avoid_print
      print('NAPPYDESK auth threw ${e.code} (user ${u?.uid ?? 'null'})');
      if (e.code == 'keychain-error' && u != null) return u;
      rethrow;
    }
    final u = auth.currentUser;
    if (u != null) return u;
    throw StateError('auth completed but no user is signed in');
  }
}
