package com.mypeblo.tidal.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Tap on the widget = read the letter RIGHT THERE. Flip the cache to `open`
 * (starting the short reading window), repaint, and leave the breadcrumb for
 * Flutter to flush the real open to Firestore later. The app is deliberately
 * NOT launched — the whole point is reading without leaving the home screen.
 */
class OpenLetterReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        SharedState.markOpenedLocally(context, READING_WINDOW_MS)

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, TidalWidgetProvider::class.java),
        )
        context.sendBroadcast(
            Intent(context, TidalWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            },
        )
    }

    private companion object {
        // The app republishes the authoritative window when it next runs, so a
        // dev/prod mismatch self-corrects.
        const val READING_WINDOW_MS = 10L * 60 * 1000
    }
}
