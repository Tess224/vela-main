package com.tess224.vela_main

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "VelaAction"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val actionId = intent.getStringExtra("action_id") ?: return
        val eventId = intent.getStringExtra("event_id") ?: ""
        val nudgeId = intent.getStringExtra("nudge_id") ?: ""
        val checkinId = intent.getStringExtra("checkin_id") ?: ""
        val type = intent.getStringExtra("type") ?: ""

        Log.d(TAG, "Action received: action=$actionId type=$type eventId=$eventId nudgeId=$nudgeId checkinId=$checkinId")

        // Dismiss the notification
        val notifKey = eventId.ifEmpty { nudgeId.ifEmpty { checkinId } }
        if (notifKey.isNotEmpty()) {
            val notifId = notifKey.hashCode().and(0x7FFFFFFF) % 100000
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(notifId)
        }

        // Read backend URLs from AndroidManifest meta-data
        val appInfo = context.packageManager.getApplicationInfo(
            context.packageName, PackageManager.GET_META_DATA
        )
        val monitoringUrl = appInfo.metaData?.getString("com.tess224.vela.MONITORING_URL") ?: ""
        val sessionPipelineUrl = appInfo.metaData?.getString("com.tess224.vela.SESSION_PIPELINE_URL") ?: ""

        // Fire HTTP call on background thread
        Thread {
            try {
                when (type) {
                    "ambient_nudge" -> {
                        if (nudgeId.isNotEmpty() && sessionPipelineUrl.isNotEmpty()) {
                            postJson(
                                "$sessionPipelineUrl/nudge/respond",
                                """{"nudge_id":"$nudgeId","response_value":"$actionId"}"""
                            )
                        }
                    }
                    "ambient_checkin" -> {
                        if (checkinId.isNotEmpty() && sessionPipelineUrl.isNotEmpty()) {
                            postJson(
                                "$sessionPipelineUrl/checkin/respond",
                                """{"checkin_id":"$checkinId","response_value":"$actionId"}"""
                            )
                        }
                    }
                    "context_confirm" -> {
                        if (eventId.isNotEmpty() && monitoringUrl.isNotEmpty()) {
                            postJson(
                                "$monitoringUrl/event/respond",
                                """{"event_id":"$eventId","context_response":"$actionId"}"""
                            )
                        }
                    }
                }
                Log.d(TAG, "Response sent successfully")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send response: ${e.message}")
            }
        }.start()
    }

    private fun postJson(url: String, json: String) {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.doOutput = true
        conn.connectTimeout = 10000
        conn.readTimeout = 10000
        conn.outputStream.use { it.write(json.toByteArray()) }
        val code = conn.responseCode
        Log.d(TAG, "POST $url -> $code")
        conn.disconnect()
    }
}
