// Proves the Flutter -> native cache path, which is the part of the widget
// design that fails SILENTLY when it is wrong.
//
// The classic failure: forgetting setAppGroupId writes to the app's own
// container instead of the shared one. Everything appears to work — the save
// succeeds, no error is thrown — and the widget simply renders an empty cache
// forever. So this asserts a real round trip through the App Group, and the
// shell check afterwards confirms the bytes landed in the shared container on
// disk rather than the app sandbox.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tidal/models/cat_breed.dart';
import 'package:tidal/models/widget_payload.dart';
import 'package:tidal/services/widget_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final openedAt = DateTime.fromMillisecondsSinceEpoch(1800000000000);

  final waiting = WidgetPayload(
    state: LetterState.waiting,
    messageId: 'letter-1',
    text: 'the sea was flat today',
    partnerName: 'Sim',
    partnerCatId: CatBreed.koala.id,
    idleLine: 'all quiet',
  );

  testWidgets('publish round-trips through the App Group', (_) async {
    await WidgetBridge.publish(waiting);

    await HomeWidget.setAppGroupId(WidgetBridge.appGroupId);
    final raw = await HomeWidget.getWidgetData<String>(WidgetBridge.stateKey);
    expect(raw, isNotNull, reason: 'nothing written to the shared container');

    final decoded = WidgetPayload.fromJson(
        jsonDecode(raw!) as Map<String, dynamic>);
    expect(decoded.state, LetterState.waiting);
    expect(decoded.messageId, 'letter-1');
    expect(decoded.partnerCatId, CatBreed.koala.id);
    // Carried even while waiting, so the cat can wake instantly on tap. The
    // widget gates rendering on `state`, never on the presence of text.
    expect(decoded.text, 'the sea was flat today');
  });

  testWidgets('the payload survives an exact encode/decode cycle', (_) async {
    final open = WidgetPayload(
      state: LetterState.open,
      messageId: 'letter-2',
      text: 'thinking of you',
      openedAt: openedAt,
      expiresAt: openedAt.add(const Duration(hours: 16)),
      partnerName: 'Sim',
      partnerCatId: CatBreed.tuxedo.id,
      canSendAt: openedAt.add(const Duration(hours: 8)),
    );

    final round = WidgetPayload.fromJson(
        jsonDecode(jsonEncode(open.toJson())) as Map<String, dynamic>);

    // Millisecond fidelity matters: Swift reads these as epoch millis and the
    // widget schedules its own sleep from expiresAt.
    expect(round.openedAt, openedAt);
    expect(round.expiresAt, openedAt.add(const Duration(hours: 16)));
    expect(round.canSendAt, openedAt.add(const Duration(hours: 8)));
    expect(round.state, LetterState.open);
  });

  testWidgets('client-side expiry overrides a stale cached state', (_) async {
    final stale = WidgetPayload(
      state: LetterState.open,
      messageId: 'letter-3',
      text: 'this one has run out',
      openedAt: openedAt,
      expiresAt: openedAt.add(const Duration(minutes: 1)),
    );

    // A cached blob can outlive its own window — Firestore TTL lags by up to
    // 24h, and the widget may not be reloaded for hours.
    expect(stale.effectiveState(openedAt), LetterState.open);
    expect(
      stale.effectiveState(openedAt.add(const Duration(hours: 1))),
      LetterState.empty,
      reason: 'past the reading window the cat just goes back to sleep',
    );
  });

  testWidgets('the pending-open breadcrumb round-trips and clears', (_) async {
    await WidgetBridge.clearPendingOpen();
    expect(await WidgetBridge.takePendingOpen(), isNull);

    // Stand in for what OpenLetterIntent writes natively on tap.
    await HomeWidget.setAppGroupId(WidgetBridge.appGroupId);
    await HomeWidget.saveWidgetData<String>(
      WidgetBridge.pendingOpenKey,
      jsonEncode({'messageId': 'letter-9', 'tappedAtMs': 1800000123000}),
    );

    final pending = await WidgetBridge.takePendingOpen();
    expect(pending, isNotNull);
    expect(pending!.messageId, 'letter-9');
    expect(pending.tappedAt.millisecondsSinceEpoch, 1800000123000);

    await WidgetBridge.clearPendingOpen();
    expect(await WidgetBridge.takePendingOpen(), isNull,
        reason: 'a breadcrumb that is never cleared re-opens forever');
  });

  testWidgets('a corrupt breadcrumb is dropped, not retried forever', (_) async {
    await HomeWidget.setAppGroupId(WidgetBridge.appGroupId);
    await HomeWidget.saveWidgetData<String>(
        WidgetBridge.pendingOpenKey, 'not json at all');

    expect(await WidgetBridge.takePendingOpen(), isNull);
    expect(await WidgetBridge.takePendingOpen(), isNull);
  });
}
