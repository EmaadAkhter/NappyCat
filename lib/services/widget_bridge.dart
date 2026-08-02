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

  /// FULLY QUALIFIED, because home_widget resolves the bare androidName as
  /// `<applicationId>.<name>` and our provider lives in the `.widget`
  /// subpackage. The bare name threw ClassNotFoundException on every update —
  /// silently — and the widget never refreshed after the app published.
  static const androidWidgetQualifiedName =
      'com.mypeblo.tidal.widget.TidalWidgetProvider';

  /// home_widget requires the App Group to be set before EVERY save on iOS, not
  /// once at startup. Forgetting it writes to the app's own container, which the
  /// extension cannot read.
  static Future<void> _prepare() =>
      HomeWidget.setAppGroupId(appGroupId);

  static Future<void> publish(WidgetPayload payload) async {
    try {
      // Desktop and web have no home-screen widget plugin at all; skip before
      // the platform channel throws.
      await _prepare();
      await HomeWidget.saveWidgetData<String>(
        stateKey,
        jsonEncode(payload.toJson()),
      );
      await HomeWidget.updateWidget(
        iOSName: iOSWidgetName,
        qualifiedAndroidName: androidWidgetQualifiedName,
      );
    } catch (_) {
      // The widget is a nicety, never a dependency. It legitimately fails when
      // no widget has been placed yet, and on Android until the provider exists.
      // Losing an update must never take the app down with it.
    }
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

/// The one-time widget-guide flag rides in the same shared prefs — no extra
/// dependency, works on both platforms.
class GuideFlag {
  static const _key = 'tidal_guide_shown';

  static Future<bool> wasShown() async {
    await HomeWidget.setAppGroupId(WidgetBridge.appGroupId);
    return (await HomeWidget.getWidgetData<String>(_key)) == '1';
  }

  static Future<void> markShown() async {
    await HomeWidget.setAppGroupId(WidgetBridge.appGroupId);
    await HomeWidget.saveWidgetData<String>(_key, '1');
  }
}

class PendingOpen {
  const PendingOpen({required this.messageId, required this.tappedAt});

  final String messageId;
  final DateTime tappedAt;
}
