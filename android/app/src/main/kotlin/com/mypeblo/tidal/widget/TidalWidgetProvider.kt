package com.mypeblo.tidal.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.widget.RemoteViews
import com.mypeblo.tidal.R
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Classic RemoteViews widget, deliberately not Glance.
 *
 * Glance would pull the whole Compose runtime and compiler plugin into an app
 * module with no other Compose, for a single tap target that
 * setOnClickPendingIntent already handles.
 *
 * Shows the PARTNER's cat: asleep when quiet, awake when they have spoken.
 */
class TidalWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val s = SharedState.load(context)
        val resolved = s.effectiveState()

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.tidal_widget).apply {
                // Awake means "an unread letter is waiting". Reading happens in
                // the app, and once the letter is closed the cat sleeps again —
                // it is a quiet signal, not a 16-hour lamp.
                setImageViewResource(
                    R.id.cat,
                    catDrawable(
                        s.partnerCatId,
                        awake = resolved == LetterState.WAITING ||
                            resolved == LetterState.OPEN,
                    ),
                )
                setTextViewText(R.id.title, title(s, resolved))
                setTextViewText(R.id.body, body(s, resolved))

                // The whole widget is the tap target, matching iOS.
                setOnClickPendingIntent(R.id.root, openIntent(context))
            }
            appWidgetManager.updateAppWidget(id, views)
        }

        // Android has no timeline, so schedule the open -> faded flip explicitly.
        // onUpdate also recomputes expiry every time, which covers the case where
        // Doze drops the alarm entirely.
        if (resolved == LetterState.OPEN && s.expiresAtMs > System.currentTimeMillis()) {
            scheduleFade(context, s.expiresAtMs)
        }
    }

    /** The signature line under the bubble. */
    private fun title(s: TidalState, resolved: LetterState): String {
        val who = s.partnerName ?: "Someone"
        return when (resolved) {
            LetterState.OPEN, LetterState.WAITING -> "— $who · tap to read"
            LetterState.FADED, LetterState.EMPTY -> ""
        }
    }

    /** What the cat is saying inside the bubble. */
    private fun body(s: TidalState, resolved: LetterState): String = when (resolved) {
        // The letter itself, comic-style, straight on the home screen.
        LetterState.OPEN, LetterState.WAITING -> s.text.orEmpty()
        LetterState.FADED -> "it drifted away…"
        LetterState.EMPTY -> s.idleLine ?: "zzz…"
    }

    /**
     * Static map, deliberately not getIdentifier: release resource shrinking
     * keeps only statically referenced drawables, so the name lookup returned 0
     * for every cat and the widget rendered an empty square where the cat
     * belonged. R.drawable references pin all sixteen.
     */
    private fun catDrawable(catId: String?, awake: Boolean): Int {
        val pair = when (catId) {
            "tuxedo" -> R.drawable.tuxedo_asleep to R.drawable.tuxedo_awake
            "ginger" -> R.drawable.ginger_asleep to R.drawable.ginger_awake
            "pumpkin" -> R.drawable.pumpkin_asleep to R.drawable.pumpkin_awake
            "koala" -> R.drawable.koala_asleep to R.drawable.koala_awake
            "jester" -> R.drawable.jester_asleep to R.drawable.jester_awake
            "blueberry" -> R.drawable.blueberry_asleep to R.drawable.blueberry_awake
            "catear" -> R.drawable.catear_asleep to R.drawable.catear_awake
            else -> R.drawable.tabby_asleep to R.drawable.tabby_awake
        }
        return if (awake) pair.second else pair.first
    }

    private fun openIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, OpenLetterReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun scheduleFade(context: Context, atMs: Long) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, TidalWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(
                AppWidgetManager.EXTRA_APPWIDGET_IDS,
                AppWidgetManager.getInstance(context).getAppWidgetIds(
                    ComponentName(context, TidalWidgetProvider::class.java),
                ),
            )
        }
        val pending = PendingIntent.getBroadcast(
            context,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Exact alarms need a user-granted permission from Android 12 onwards.
        // Falling back to an inexact alarm is right: the cat sleeping a few
        // minutes late is far better than asking for a scary permission, and
        // onUpdate recomputes expiry regardless.
        val canBeExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarms.canScheduleExactAlarms()
        if (canBeExact) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC, atMs, pending)
        } else {
            alarms.set(AlarmManager.RTC, atMs, pending)
        }
    }
}
