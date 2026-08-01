import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'services/background_refresh.dart';
import 'services/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (Config.useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator(
      Config.emulatorHost,
      Config.firestoreEmulatorPort,
    );
    await FirebaseAuth.instance.useAuthEmulator(
      Config.emulatorHost,
      Config.authEmulatorPort,
    );
  }

  services = Services.create();

  // Phase 4: periodic background sync keeps the widget honest while the app is
  // closed. Best-effort by design — failures just mean a staler widget.
  try {
    await BackgroundRefresh.register();
  } catch (_) {}

  runApp(const TidalApp());
}
