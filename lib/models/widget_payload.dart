import 'cat_breed.dart';

/// What the cat is doing right now. Drives the hero card, the in-app preview,
/// and both native home-screen widgets from one enum.
enum LetterState {
  /// Nothing waiting. Tapping wakes the cat for an idle line.
  empty,

  /// A letter has arrived but has NOT been opened. The text is deliberately
  /// withheld from every surface in this state — showing it would start the
  /// clock without the reader deciding to.
  waiting,

  /// Opened and ticking. Visible until [WidgetPayload.expiresAt].
  open,

  /// It was opened and its time ran out.
  faded;

  static LetterState fromName(String? s) =>
      LetterState.values.firstWhere((e) => e.name == s, orElse: () => LetterState.empty);
}

/// The single JSON blob shared between Flutter and the native widgets.
///
/// One blob rather than N keys on purpose: native reads the whole thing at once,
/// so there is no window where it can see a half-updated state (an `open` flag
/// with last letter's text, say).
class WidgetPayload {
  const WidgetPayload({
    required this.state,
    this.messageId,
    this.text,
    this.openedAt,
    this.expiresAt,
    this.partnerName,
    this.partnerCatId,
    this.idleLine,
    this.canSendAt,
  });

  static const version = 1;

  final LetterState state;
  final String? messageId;

  /// Present whenever a letter exists, including while [state] is `waiting`.
  /// That is safe: the body is already on the device in Firestore's local cache
  /// the moment the doc syncs, and the App Group container is sandboxed to this
  /// app and its extension. Carrying it is what lets the widget wake instantly
  /// on tap. `state` — not absence of text — is what gates rendering.
  final String? text;

  final DateTime? openedAt;
  final DateTime? expiresAt;
  final String? partnerName;
  final String? partnerCatId;
  final String? idleLine;

  /// When the send button unlocks. Null means "can send now".
  final DateTime? canSendAt;

  CatBreed get partnerBreed => CatBreed.fromId(partnerCatId);

  /// True once the open window has run out. Callers must use this rather than
  /// trusting [state], because Firestore TTL deletion lags by up to 24h and a
  /// cached payload can outlive its own expiry.
  bool hasExpiredAt(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  /// The state to actually render. For `open`, [expiresAt] is the READING
  /// window (openedAt + a few minutes), not the letter's 16h life — once it
  /// passes the cat simply goes back to sleep; the letter itself stays in the
  /// journal until its real expiry.
  LetterState effectiveState(DateTime now) =>
      state == LetterState.open && hasExpiredAt(now)
          ? LetterState.empty
          : state;

  static int? _ms(DateTime? d) => d?.millisecondsSinceEpoch;
  static DateTime? _at(dynamic ms) => ms == null || ms == 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());

  Map<String, dynamic> toJson() => {
        'v': version,
        'state': state.name,
        'messageId': messageId,
        'text': text,
        'openedAtMs': _ms(openedAt) ?? 0,
        'expiresAtMs': _ms(expiresAt) ?? 0,
        'partnerName': partnerName,
        'partnerCatId': partnerCatId,
        'idleLine': idleLine,
        'canSendAtMs': _ms(canSendAt) ?? 0,
      };

  factory WidgetPayload.fromJson(Map<String, dynamic> j) => WidgetPayload(
        state: LetterState.fromName(j['state'] as String?),
        messageId: j['messageId'] as String?,
        text: j['text'] as String?,
        openedAt: _at(j['openedAtMs']),
        expiresAt: _at(j['expiresAtMs']),
        partnerName: j['partnerName'] as String?,
        partnerCatId: j['partnerCatId'] as String?,
        idleLine: j['idleLine'] as String?,
        canSendAt: _at(j['canSendAtMs']),
      );

  WidgetPayload copyWith({
    LetterState? state,
    String? messageId,
    String? text,
    DateTime? openedAt,
    DateTime? expiresAt,
    String? partnerName,
    String? partnerCatId,
    String? idleLine,
    DateTime? canSendAt,
  }) =>
      WidgetPayload(
        state: state ?? this.state,
        messageId: messageId ?? this.messageId,
        text: text ?? this.text,
        openedAt: openedAt ?? this.openedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        partnerName: partnerName ?? this.partnerName,
        partnerCatId: partnerCatId ?? this.partnerCatId,
        idleLine: idleLine ?? this.idleLine,
        canSendAt: canSendAt ?? this.canSendAt,
      );
}
