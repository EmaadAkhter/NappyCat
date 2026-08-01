import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';

import '../config.dart';
import '../firebase_options.dart';
import '../models/tidal_message.dart';
import '../models/widget_payload.dart';
import 'idle_chatter.dart';
import 'widget_bridge.dart';

/// Phase 4: the widget's lifeline while the app is closed.
///
/// There is no push in this app, and the widget renders only what the app has
/// published — so without this, a letter could sit unseen until the app was
/// next opened, which defeats the ambient widget entirely. A periodic
/// background task syncs Firestore once and republishes the cache.
///
/// Android's WorkManager gives a reliable ~15-minute floor. iOS's
/// BGAppRefreshTask is opportunistic — iOS decides when, and for a
/// rarely-opened app that can stretch to hours. For an app whose thesis is
/// slowness, "the widget may lag a little" is the accepted cost of having no
/// push and no server.
class BackgroundRefresh {
  const BackgroundRefresh._();

  /// Also the BGTaskSchedulerPermittedIdentifiers entry on iOS — the strings
  /// must match exactly or iOS silently never runs the task.
  static const taskId = 'com.mypeblo.tidal.refresh';

  static Future<void> register() async {
    await Workmanager().initialize(backgroundRefreshDispatcher);
    await Workmanager().registerPeriodicTask(
      taskId,
      taskId,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
    );
  }

  /// One sync: read the world, publish the payload. Runs in a background
  /// isolate with its own Firebase instance.
  static Future<void> runOnce() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // never signed in; nothing to publish

    final db = FirebaseFirestore.instance;

    final me = await db.collection('users').doc(uid).get();
    final pairId = me.data()?['pairId'] as String?;
    if (pairId == null) return;

    final pair = await db.collection('pairs').doc(pairId).get();
    final members =
        List<String>.from(pair.data()?['memberIds'] as List? ?? const []);
    final partnerId = members.firstWhere((m) => m != uid, orElse: () => '');

    Map<String, dynamic>? partner;
    if (partnerId.isNotEmpty) {
      partner = (await db.collection('users').doc(partnerId).get()).data();
    }

    final snap = await db
        .collection('pairs')
        .doc(pairId)
        .collection('messages')
        .where('recipientId', isEqualTo: uid)
        .orderBy('sentAt', descending: true)
        .limit(1)
        .get();

    // No server-corrected clock in the background isolate; the device clock is
    // close enough for a 15-minute cadence, and the foreground app republishes
    // the corrected view on next open.
    final now = DateTime.now();
    TidalMessage? letter;
    if (snap.docs.isNotEmpty) {
      final m = TidalMessage.fromDoc(snap.docs.first);
      if (m.isVisibleAt(now)) letter = m;
    }

    final openedAt = letter?.openedAt;
    final reading = letter != null &&
        openedAt != null &&
        now.isBefore(openedAt.add(Config.readingWindow));
    final unread = letter != null && openedAt == null;

    final lastSentAt =
        (me.data()?['lastSentAt'] as Timestamp?)?.toDate();

    await WidgetBridge.publish(WidgetPayload(
      state: reading
          ? LetterState.open
          : unread
              ? LetterState.waiting
              : LetterState.empty,
      messageId: (reading || unread) ? letter.id : null,
      text: (reading || unread) ? letter.text : null,
      openedAt: openedAt,
      expiresAt: reading ? openedAt.add(Config.readingWindow) : null,
      partnerName:
          partner?['displayName'] as String? ?? letter?.senderName,
      partnerCatId: partner?['catId'] as String? ?? letter?.senderCatId,
      idleLine: IdleChatter.random(),
      canSendAt: lastSentAt?.add(Config.sendCooldown),
    ));
  }
}

/// Top-level entry point for the background isolate. Must be a pragma'd
/// top-level function or release-mode tree shaking drops it and the task
/// silently never runs.
@pragma('vm:entry-point')
void backgroundRefreshDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await BackgroundRefresh.runOnce();
    } catch (_) {
      // A failed sync is just a stale widget for another cycle. Returning true
      // avoids WorkManager's retry storm for what is best-effort by design.
    }
    return true;
  });
}
