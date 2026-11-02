package com.akshay.expensetracker

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import androidx.core.content.ContextCompat

/** Catches bank / UPI SMS as they arrive, even when the app is closed. */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        // the user can switch detection off in the app
        val enabled = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getBoolean("flutter.sms_enabled", false)
        if (!enabled) return

        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        // long messages arrive in several parts; join them per sender
        parts.groupBy { it.originatingAddress ?: "" }.forEach { (address, messages) ->
            val body = messages.joinToString("") { it.messageBody ?: "" }
            if (!SmsStore.looksFinancial(body)) return@forEach
            val date = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()
            val appOpen = SmsStore.liveSink != null
            SmsStore.onMessage(context, address, body, date)
            // when the app is open it asks in-app instead
            if (!appOpen) notify(context, body, SmsStore.keyOf(address, date))
        }
    }

    private fun notify(context: Context, body: String, key: String) {
        if (!canNotify(context)) return
        ensureChannel(context)

        val amount = Regex("(?:rs\\.?|inr|₹)\\s*([\\d,]+(?:\\.\\d{1,2})?)", RegexOption.IGNORE_CASE).find(body)?.groupValues?.get(1)
            ?: Regex("(?:debited|credited)\\s+(?:by|with|for)\\s+([\\d,]+(?:\\.\\d{1,2})?)", RegexOption.IGNORE_CASE).find(body)?.groupValues?.get(1)
        val credit = Regex("credited|received|refund", RegexOption.IGNORE_CASE).containsMatchIn(body) &&
            !Regex("debited|spent|paid", RegexOption.IGNORE_CASE).containsMatchIn(body)
        val what = when {
            amount == null -> "A payment"
            credit -> "₹$amount received"
            else -> "₹$amount spent"
        }
        val id = notificationId(key)
        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_logo)
            .setColor(BRAND)
            .setAutoCancel(true)
            .setContentIntent(openApp(context))

        if (SmsStore.isClear(context, body)) {
            builder.setContentTitle(what).setContentText("xp picked this up from your SMS. Tap to see it.")
        } else {
            // the SMS doesn't say what this was for: ask right in the notification
            val replyIntent = Intent(context, LabelReceiver::class.java)
                .setAction(LabelReceiver.ACTION)
                .putExtra(LabelReceiver.EXTRA_KEY, key)
                .putExtra(LabelReceiver.EXTRA_ID, id)
            val reply = NotificationCompat.Action.Builder(
                R.drawable.ic_stat_logo,
                "Add name",
                PendingIntent.getBroadcast(context, id, replyIntent, PendingIntent.FLAG_UPDATE_CURRENT or mutableFlag()),
            ).addRemoteInput(
                RemoteInput.Builder(LabelReceiver.EXTRA_REPLY).setLabel("What was it for? e.g. lunch").build()
            ).setAllowGeneratedReplies(false).build()

            builder.setContentTitle("$what · what was it for?")
                .setContentText("Your bank SMS didn't say. Reply with a name, pick a category, or tap to choose.")
                .setStyle(NotificationCompat.BigTextStyle().bigText("Your bank SMS didn't say what this was. Reply with a name like \"lunch\" or \"medicines\", pick a category below, or tap to choose in the app."))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .addAction(reply)
            val quick = if (credit) listOf("Salary", "Gift") else listOf("Food", "Shopping")
            quick.forEachIndexed { i, category ->
                val pick = Intent(context, LabelReceiver::class.java)
                    .setAction(LabelReceiver.ACTION)
                    .putExtra(LabelReceiver.EXTRA_KEY, key)
                    .putExtra(LabelReceiver.EXTRA_ID, id)
                    .putExtra(LabelReceiver.EXTRA_CATEGORY, category)
                builder.addAction(
                    0,
                    category,
                    PendingIntent.getBroadcast(context, id * 10 + i + 1, pick, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
                )
            }
        }
        NotificationManagerCompat.from(context).notify(id, builder.build())
    }

    companion object {
        const val CHANNEL = "detected_transactions"
        const val BRAND = 0xFF16A34A.toInt()

        fun notificationId(key: String) = key.hashCode() and 0x0FFFFFFF

        fun canNotify(context: Context) = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

        fun ensureChannel(context: Context) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(CHANNEL, "Detected transactions", NotificationManager.IMPORTANCE_HIGH).apply {
                        description = "Payments picked up from your bank SMS"
                    }
                )
            }
        }

        fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // inline replies need a mutable PendingIntent so the system can attach the typed text
        private fun mutableFlag() = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
    }
}
