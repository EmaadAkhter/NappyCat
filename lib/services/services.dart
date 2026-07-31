import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'clock.dart';
import 'message_service.dart';
import 'pairing_service.dart';

/// Plain container, wired once in main().
///
/// ponytail: no DI framework. Two people, one screen graph — an injectable
/// singleton is the whole requirement, and riverpod/get_it would be ceremony
/// around a single object.
class Services {
  Services._(this.auth, this.pairing, this.messages, this.clock, this.db);

  final AuthService auth;
  final PairingService pairing;
  final MessageService messages;
  final Clock clock;
  final FirebaseFirestore db;

  factory Services.create() {
    final db = FirebaseFirestore.instance;
    final clock = Clock(db);
    return Services._(
      AuthService(FirebaseAuth.instance, db),
      PairingService(db),
      MessageService(db, clock),
      clock,
      db,
    );
  }
}

late Services services;
