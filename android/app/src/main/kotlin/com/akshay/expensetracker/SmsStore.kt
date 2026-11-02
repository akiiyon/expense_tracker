package com.akshay.expensetracker

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

/** Keeps transaction-looking SMS until the Flutter side picks them up. */
object SmsStore {
    private const val PREFS = "expensify_sms"
    private const val KEY = "pending"
    private const val MAX_PENDING = 200

    /** Set while the app is open, so new messages show up instantly. */
    @Volatile
    var liveSink: EventChannel.EventSink? = null

    private val amountRe = Regex("(rs\\.?|inr|₹)\\s*[\\d,]+|(debited|credited)\\s+(by|with|for)\\s+[\\d,]+", RegexOption.IGNORE_CASE)
    private val verbRe = Regex("debited|credited|spent|paid|sent|withdrawn|received|purchase|txn|transferred|refund", RegexOption.IGNORE_CASE)
    private val otpRe = Regex("\\botp\\b|one.time password|verification code", RegexOption.IGNORE_CASE)

    /** Cheap pre-filter. The real parsing happens in Dart (lib/sms/sms_parser.dart). */
    fun looksFinancial(body: String): Boolean =
        amountRe.containsMatchIn(body) && verbRe.containsMatchIn(body) && !otpRe.containsMatchIn(body)

    /**
     * True when the SMS names something we can categorise (Swiggy, Uber, salary...).
     * Uses the same keyword list as the Dart parser, which the app saves on start.
     */
    fun isClear(context: Context, body: String): Boolean {
        val words = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.sms_category_words", null) ?: return false
        val text = body.lowercase()
        return words.split('|').any { w ->
            w.isNotBlank() && Regex("(^|[^a-z])${Regex.escape(w.lowercase())}(s|es)?([^a-z]|$)").containsMatchIn(text)
        }
    }

    fun keyOf(address: String, date: Long) = "$address|$date"

    fun onMessage(context: Context, address: String, body: String, date: Long) {
        val map = mapOf("address" to address, "body" to body, "date" to date)
        val sink = liveSink
        if (sink != null) {
            Handler(Looper.getMainLooper()).post { sink.success(map) }
            return
        }
        synchronized(this) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val list = JSONArray(prefs.getString(KEY, "[]"))
            list.put(JSONObject(map))
            while (list.length() > MAX_PENDING) list.remove(0)
            prefs.edit().putString(KEY, list.toString()).apply()
        }
    }

    /** Saves the user's answer from the notification onto the queued message. */
    fun setLabel(context: Context, key: String, label: String?, category: String?): Boolean = synchronized(this) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val list = JSONArray(prefs.getString(KEY, "[]"))
        for (i in 0 until list.length()) {
            val o = list.getJSONObject(i)
            if (keyOf(o.optString("address"), o.optLong("date")) == key) {
                if (label != null) o.put("label", label)
                if (category != null) o.put("labelCategory", category)
                prefs.edit().putString(KEY, list.toString()).apply()
                return true
            }
        }
        false
    }

    fun takePending(context: Context): List<Map<String, Any>> = synchronized(this) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val list = JSONArray(prefs.getString(KEY, "[]"))
        prefs.edit().remove(KEY).apply()
        // the app takes over from here, so any "what was it for?" notifications are no longer needed
        if (list.length() > 0) NotificationManagerCompat.from(context).cancelAll()
        (0 until list.length()).map { i ->
            val o = list.getJSONObject(i)
            mapOf(
                "address" to o.optString("address"),
                "body" to o.optString("body"),
                "date" to o.optLong("date"),
                "label" to o.optString("label"),
                "labelCategory" to o.optString("labelCategory"),
            )
        }
    }
}
