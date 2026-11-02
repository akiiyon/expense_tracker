package com.akshay.expensetracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput

/** Handles the answer from the "what was it for?" notification (typed name or tapped category). */
class LabelReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        val key = intent.getStringExtra(EXTRA_KEY) ?: return
        val id = intent.getIntExtra(EXTRA_ID, 0)
        val label = RemoteInput.getResultsFromIntent(intent)?.getCharSequence(EXTRA_REPLY)?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        val category = intent.getStringExtra(EXTRA_CATEGORY)
        if (label == null && category == null) return

        val saved = SmsStore.setLabel(context, key, label, category)
        if (!SmsReceiver.canNotify(context)) return

        // replace the question so the reply spinner stops, then let it fade away
        val done = NotificationCompat.Builder(context, SmsReceiver.CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_logo)
            .setColor(SmsReceiver.BRAND)
            .setContentTitle(if (saved) "Got it! Saved as ${label ?: category}" else "Open the app to finish this one")
            .setContentText("xp will add it next time you open the app.")
            .setContentIntent(SmsReceiver.openApp(context))
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setTimeoutAfter(4000)
            .build()
        NotificationManagerCompat.from(context).notify(id, done)
    }

    companion object {
        const val ACTION = "com.akshay.expensetracker.SMS_LABEL"
        const val EXTRA_KEY = "key"
        const val EXTRA_ID = "notification_id"
        const val EXTRA_REPLY = "reply"
        const val EXTRA_CATEGORY = "category"
    }
}
