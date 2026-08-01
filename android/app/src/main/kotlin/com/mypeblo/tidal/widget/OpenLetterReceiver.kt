package com.mypeblo.tidal.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Android counterpart of iOS OpenLetterIntent.
 *
 * Never touches Firestore: the widget process has no auth. It flips the local
 * cache so the cat wakes instantly, drops a breadcrumb, and launches the app,
 * which flushes the real open to the server on resume.
 */
class OpenLetterReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val before = SharedState.load(context).effectiveState()

        if (before == LetterState.WAITING) {
            SharedState.markTappedLocally(context)
        }

        // Repaint immediately, before the app has finished launching.
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

        // A real letter must reach Firestore, so opening it opens the app. An
        // idle tap just wakes the cat in place and leaves you alone.
        if (before == LetterState.WAITING) {
            context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ?.let(context::startActivity)
        }
    }
}
