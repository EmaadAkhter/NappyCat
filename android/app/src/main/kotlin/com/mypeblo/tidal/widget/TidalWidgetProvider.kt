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
                setImageViewResource(
                    R.id.cat,
                    catDrawable(context, s.partnerCatId, awake = resolved == LetterState.OPEN),
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

    private fun title(s: TidalState, resolved: LetterState): String {
        val who = s.partnerName ?: "Someone"
        return when (resolved) {
            LetterState.OPEN -> who
            LetterState.WAITING -> "$who left you something"
            LetterState.FADED -> "It drifted away"
            LetterState.EMPTY -> "All quiet"
        }
    }

    /** WAITING must never reveal the body — that is the point of read-time expiry. */
    private fun body(s: TidalState, resolved: LetterState): String = when (resolved) {
        LetterState.OPEN -> s.text.orEmpty()
        LetterState.WAITING -> "Tap to read it"
        LetterState.FADED -> "That letter has faded"
        LetterState.EMPTY -> s.idleLine ?: "Nothing yet"
    }

    private fun catDrawable(context: Context, catId: String?, awake: Boolean): Int {
        val id = if (catId.isNullOrBlank()) "tabby" else catId
        val name = "${id}_${if (awake) "awake" else "asleep"}"
        val res = context.resources.getIdentifier(name, "drawable", context.packageName)
        return if (res != 0) res else {
            context.resources.getIdentifier(
                if (awake) "tabby_awake" else "tabby_asleep",
                "drawable",
                context.packageName,
            )
        }
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
