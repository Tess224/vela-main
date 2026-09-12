package com.tess224.vela_main

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Handles notification action button taps.
 *
 * This runs with no Flutter engine and no Supabase session, so it cannot send
 * a user JWT. It authenticates with the single-use response token that the
 * backend put in the push payload. Anything that fails goes to
 * PendingResponseStore and is drained by the app on next launch.
 */
class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "VelaAction"
        private const val TIMEOUT_MS = 10_000
    }

    private data class Target(
        val url: String,
        val body: JSONObject,
        val type: String,
        val id: String,
    )

    override fun onReceive(context: Context, intent: Intent) {
        val actionId = intent.getStringExtra("action_id") ?: return
        val eventId = intent.getStringExtra("event_id") ?: ""
        val nudgeId = intent.getStringExtra("nudge_id") ?: ""
        val checkinId = intent.getStringExtra("checkin_id") ?: ""
        val responseToken = intent.getStringExtra("response_token") ?: ""
        val type = intent.getStringExtra("type") ?: ""
        val tappedAt = System.currentTimeMillis()

        Log.d(TAG, "Action received: action=$actionId type=$type hasToken=${responseToken.isNotEmpty()}")

        // Dismiss the notification immediately — cheap and synchronous.
        val notifKey = eventId.ifEmpty { nudgeId.ifEmpty { checkinId } }
        if (notifKey.isNotEmpty()) {
            val notifId = notifKey.hashCode().and(0x7FFFFFFF) % 100000
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(notifId)
        }

        val target = resolveTarget(context, type, actionId, eventId, nudgeId, checkinId)
        if (target == null) {
            Log.w(TAG, "No deliverable target for type=$type")
            return
        }

        // goAsync keeps the process alive for the request. Without it Android
        // may kill us the instant onReceive returns, mid-flight.
        val pending = goAsync()
        Thread {
            var delivered = false
            try {
                val code = postJson(target.url, target.body.toString(), responseToken)
                // 4xx other than 401/408/429 means the server rejected the
                // content itself. Retrying later cannot help, so do not queue.
                delivered = code in 200..299 ||
                    (code in 400..499 && code != 401 && code != 408 && code != 429)
                Log.d(TAG, "POST ${target.url} -> $code")
            } catch (e: Exception) {
                Log.e(TAG, "Send failed: ${e.message}")
            } finally {
                if (!delivered) {
                    try {
                        PendingResponseStore.enqueue(
                            context, target.type, target.id, actionId, responseToken, tappedAt,
                        )
                        Log.d(TAG, "Queued ${target.type} response for later delivery")
                    } catch (e: Exception) {
                        Log.e(TAG, "Queue write failed: ${e.message}")
                    }
                }
                pending.finish()
            }
        }.start()
    }

    private fun resolveTarget(
        context: Context,
        type: String,
        actionId: String,
        eventId: String,
        nudgeId: String,
        checkinId: String,
    ): Target? {
        val appInfo = context.packageManager.getApplicationInfo(
            context.packageName, PackageManager.GET_META_DATA,
        )
        val monitoringUrl = appInfo.metaData?.getString("com.tess224.vela.MONITORING_URL") ?: ""
        val sessionUrl = appInfo.metaData?.getString("com.tess224.vela.SESSION_PIPELINE_URL") ?: ""

        // Built with JSONObject rather than string templates — action labels
        // are human copy and will eventually contain a quote character.
        return when {
            type == "ambient_nudge" && nudgeId.isNotEmpty() && sessionUrl.isNotEmpty() -> Target(
                url = "$sessionUrl/nudge/respond",
                body = JSONObject()
                    .put("nudge_id", nudgeId)
                    .put("response_value", actionId),
                type = "nudge",
                id = nudgeId,
            )
            type == "ambient_checkin" && checkinId.isNotEmpty() && sessionUrl.isNotEmpty() -> Target(
                url = "$sessionUrl/checkin/respond",
                body = JSONObject()
                    .put("checkin_id", checkinId)
                    .put("response_value", actionId),
                type = "checkin",
                id = checkinId,
            )
            type == "context_confirm" && eventId.isNotEmpty() && monitoringUrl.isNotEmpty() -> Target(
                url = "$monitoringUrl/event/respond",
                body = JSONObject()
                    .put("event_id", eventId)
                    .put("context_response", actionId),
                type = "event",
                id = eventId,
            )
            else -> null
        }
    }

    private fun postJson(url: String, json: String, responseToken: String): Int {
        val conn = URL(url).openConnection() as HttpURLConnection
        return try {
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            if (responseToken.isNotEmpty()) {
                conn.setRequestProperty("x-vela-response-token", responseToken)
            }
            conn.doOutput = true
            conn.connectTimeout = TIMEOUT_MS
            conn.readTimeout = TIMEOUT_MS
            conn.outputStream.use { it.write(json.toByteArray(Charsets.UTF_8)) }
            conn.responseCode
        } finally {
            conn.disconnect()
        }
    }
}
