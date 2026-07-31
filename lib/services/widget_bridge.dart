import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/widget_payload.dart';

/// The only thing that talks to the native home-screen widgets.
///
/// Flutter is the sole writer of the state blob; native is the sole writer of
/// the pending-open breadcrumb. Keeping those directions strict is what stops
/// the two sides fighting over the same key.
class WidgetBridge {
  const WidgetBridge._();

  static const appGroupId = 'group.com.mypeblo.tidal';
  static const stateKey = 'tidal_state';
  static const pendingOpenKey = 'tidal_pending_open';

  /// Must match TidalWidget.kind and SharedStore.widgetKind exactly. A mismatch
  /// fails silently — the widget just never updates — so it is defined once here
  /// and referenced everywhere.
  static const iOSWidgetName = 'TidalWidget';
  static const androidWidgetName = 'TidalWidgetProvider';

  /// home_widget requires the App Group to be set before EVERY save on iOS, not
  /// once at startup. Forgetting it writes to the app's own container, which the
  /// extension cannot read.
  static Future<void> _prepare() =>
      HomeWidget.setAppGroupId(appGroupId);

  static Future<void> publish(WidgetPayload payload) async {
    await _prepare();
    await HomeWidget.saveWidgetData<String>(
      stateKey,
      jsonEncode(payload.toJson()),
    );
    await HomeWidget.updateWidget(
      iOSName: iOSWidgetName,
      androidName: androidWidgetName,
    );
  }

  /// What the widget left behind when it was tapped, or null.
  ///
  /// The timestamp is the NATIVE one — the instant the user actually tapped —
  /// so the server records when they really opened it, not when the app got
  /// around to syncing. That matters when the tap happened offline.
  static Future<PendingOpen?> takePendingOpen() async {
    await _prepare();
    final raw = await HomeWidget.getWidgetData<String>(pendingOpenKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final id = j['messageId'] as String?;
      final ms = (j['tappedAtMs'] as num?)?.toInt();
      if (id == null || ms == null) return null;
      return PendingOpen(
        messageId: id,
        tappedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      );
    } catch (_) {
      // Corrupt breadcrumb: drop it rather than retrying forever.
      await clearPendingOpen();
      return null;
    }
  }

  static Future<void> clearPendingOpen() async {
    await _prepare();
    await HomeWidget.saveWidgetData<String>(pendingOpenKey, '');
  }
}

class PendingOpen {
  const PendingOpen({required this.messageId, required this.tappedAt});

  final String messageId;
  final DateTime tappedAt;
}
