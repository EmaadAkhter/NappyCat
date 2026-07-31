import 'package:firebase_core/firebase_core.dart';

/// PLACEHOLDER — emulator-only credentials.
///
/// The `demo-` project prefix makes the Firebase SDKs skip credential
/// validation entirely and talk only to local emulators, which is what lets the
/// whole messaging layer be built and tested without touching the cloud.
///
/// Replace this file by running, once the real project is authorized:
///
///     flutterfire configure --project napcat-2e042
///
/// That regenerates it with real keys for both platforms. Until then, always
/// run with --dart-define=USE_EMULATOR=true.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const FirebaseOptions currentPlatform = FirebaseOptions(
    // FIRInstallations validates the SHAPE of this key at startup, before any
    // network call and regardless of the demo- project prefix: it must be 39
    // characters and begin with 'A', or the app aborts on launch. So this is a
    // well-formed fake, not a real credential.
    apiKey: 'AIzaSyDemoKeyForEmulatorUseOnly00000000',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'demo-tidal',
    storageBucket: 'demo-tidal.appspot.com',
  );
}
