package com.akshay.expensetracker

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "expensify/sms").setMethodCallHandler { call, result ->
            when (call.method) {
                "readInbox" -> {
                    if (!hasSmsPermission()) {
                        result.error("NO_PERMISSION", "READ_SMS not granted", null)
                        return@setMethodCallHandler
                    }
                    val since = (call.argument<Number>("since") ?: 0).toLong()
                    val limit = (call.argument<Number>("limit") ?: 500).toInt()
                    Thread {
                        val messages = try {
                            readInbox(since, limit)
                        } catch (e: Exception) {
                            runOnUiThread { result.error("READ_FAILED", e.message, null) }
                            return@Thread
                        }
                        runOnUiThread { result.success(messages) }
                    }.start()
                }
                // messages the receiver saved while the app was closed
                "takePending" -> result.success(SmsStore.takePending(this))
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "expensify/sms/incoming").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                SmsStore.liveSink = events
            }

            override fun onCancel(arguments: Any?) {
                SmsStore.liveSink = null
            }
        })
    }

    private fun hasSmsPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    private fun readInbox(since: Long, limit: Int): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("address", "body", "date"),
            "date > ?",
            arrayOf(since.toString()),
            "date DESC",
        )?.use { cursor ->
            val addressIdx = cursor.getColumnIndexOrThrow("address")
            val bodyIdx = cursor.getColumnIndexOrThrow("body")
            val dateIdx = cursor.getColumnIndexOrThrow("date")
            while (cursor.moveToNext() && out.size < limit) {
                val body = cursor.getString(bodyIdx) ?: continue
                if (!SmsStore.looksFinancial(body)) continue
                out.add(
                    mapOf(
                        "address" to (cursor.getString(addressIdx) ?: ""),
                        "body" to body,
                        "date" to cursor.getLong(dateIdx),
                    )
                )
            }
        }
        return out
    }
}
