package com.mypeblo.tidal.widget

import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

/**
 * Android half of the shared-cache contract. Mirrors
 * ios/TidalWidget/Shared/SharedState.swift and lib/models/widget_payload.dart —
 * nothing links the three, so tools/check_payload_contract.py diffs them.
 *
 * Flutter is the only writer of `tidal_state`; the widget is the only writer of
 * `tidal_pending_open`.
 */
enum class LetterState { EMPTY, WAITING, OPEN, FADED;

    companion object {
        fun from(raw: String?) = when (raw) {
            "waiting" -> WAITING
            "open" -> OPEN
            "faded" -> FADED
            else -> EMPTY
        }
    }
}

data class TidalState(
    val state: LetterState = LetterState.EMPTY,
    val messageId: String? = null,
    /** Present even while waiting; rendering is gated on [state], never on this. */
    val text: String? = null,
    val expiresAtMs: Long = 0,
    val partnerName: String? = null,
    val partnerCatId: String? = null,
    val idleLine: String? = null,
) {
    /**
     * A cached blob can outlive its own window — the widget may not be updated
     * for hours — so expiry is always recomputed rather than trusted.
     */
    fun effectiveState(now: Long = System.currentTimeMillis()): LetterState =
        if (state == LetterState.OPEN && expiresAtMs in 1..now) LetterState.EMPTY else state
}

object SharedState {
    const val STATE_KEY = "tidal_state"
    const val PENDING_OPEN_KEY = "tidal_pending_open"

    private fun prefs(context: Context) = HomeWidgetPlugin.getData(context)

    fun load(context: Context): TidalState {
        val raw = prefs(context).getString(STATE_KEY, null) ?: return TidalState()
        return try {
            val j = JSONObject(raw)
            TidalState(
                state = LetterState.from(j.optString("state", "empty")),
                messageId = j.optStringOrNull("messageId"),
                text = j.optStringOrNull("text"),
                expiresAtMs = j.optLong("expiresAtMs", 0),
                partnerName = j.optStringOrNull("partnerName"),
                partnerCatId = j.optStringOrNull("partnerCatId"),
                idleLine = j.optStringOrNull("idleLine"),
            )
        } catch (_: Exception) {
            // A corrupt blob renders the quiet state rather than crashing the
            // launcher, which is what an uncaught exception here would do.
            TidalState()
        }
    }

    /**
     * Reveal in place: flip the cached state to `open` so the letter shows on
     * the widget immediately, give it a short reading window, and leave a
     * breadcrumb so Flutter flushes the real open to Firestore next time the
     * app runs. No app launch — reading happens right here.
     */
    fun markOpenedLocally(context: Context, readingWindowMs: Long) {
        val p = prefs(context)
        val raw = p.getString(STATE_KEY, null) ?: return
        try {
            val j = JSONObject(raw)
            if (j.optString("state") != "waiting") return
            val messageId = j.optStringOrNull("messageId") ?: return

            val now = System.currentTimeMillis()
            j.put("state", "open")
            j.put("openedAtMs", now)
            j.put("expiresAtMs", now + readingWindowMs)

            p.edit()
                .putString(STATE_KEY, j.toString())
                .putString(
                    PENDING_OPEN_KEY,
                    JSONObject()
                        .put("messageId", messageId)
                        .put("tappedAtMs", now)
                        .toString(),
                )
                .apply()
        } catch (_: Exception) {
            // Leave the cache untouched; the app reconciles from Firestore.
        }
    }

    private fun JSONObject.optStringOrNull(key: String): String? =
        if (isNull(key)) null else optString(key, "").ifEmpty { null }
}
