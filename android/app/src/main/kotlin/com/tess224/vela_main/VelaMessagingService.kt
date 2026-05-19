package com.tess224.vela_main

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONArray

class VelaMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "VelaFCM"
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: "unknown"

        Log.d(TAG, "onMessageReceived called — type=$type")
        Log.d(TAG, "data keys: ${data.keys}")
        Log.d(TAG, "has notification field: ${message.notification != null}")
        Log.d(TAG, "actions field: ${data["actions"]}")

        if (type == "context_confirm" || type == "ambient_nudge") {
            Log.d(TAG, "Routing to showWithActions for type=$type")
            showWithActions(data)
        } else {
            Log.d(TAG, "Passing to super (Flutter handler)")
            super.onMessageReceived(message)
        }
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "New FCM token generated: ${token.take(20)}...")
        super.onNewToken(token)
    }

    private fun showWithActions(data: Map<String, String>) {
        val context: Context = this
        val channelId = "vela_alerts"
        val title = data["title"] ?: "Vela"
        val body = data["body"] ?: ""
        val eventId = data["event_id"] ?: data["nudge_id"] ?: ""

        Log.d(TAG, "showWithActions — title=$title body=$body eventId=$eventId")

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            channelId,
            "Vela Alerts",
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = "Health deviation alerts from Vela"
        manager.createNotificationChannel(channel)

        // Tap intent — opens the app
        val tapIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (tapIntent != null) {
            tapIntent.putExtra("type", "context_confirm")
            tapIntent.putExtra("event_id", eventId)
            for ((k, v) in data) {
                tapIntent.putExtra(k, v)
            }
            tapIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPending = PendingIntent.getActivity(
            context, eventId.hashCode(), tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(tapPending)

        // Parse and add action buttons
        val actionsJson = data["actions"]
        Log.d(TAG, "Parsing actions JSON: $actionsJson")

        if (!actionsJson.isNullOrEmpty()) {
            try {
                val arr = JSONArray(actionsJson)
                Log.d(TAG, "Parsed ${arr.length()} actions")
                for (i in 0 until arr.length()) {
                    val label = arr.getString(i)
                    Log.d(TAG, "Adding action button: $label")

                    val actionIntent = Intent(context, NotificationActionReceiver::class.java)
                    actionIntent.action = "com.tess224.vela_main.NOTIFICATION_ACTION"
                    actionIntent.putExtra("action_id", label)
                    actionIntent.putExtra("event_id", eventId)
                    actionIntent.putExtra("nudge_id", data["nudge_id"] ?: "")
                    actionIntent.putExtra("type", data["type"] ?: "")

                    val uniqueKey = (eventId.ifEmpty { data["nudge_id"] ?: "" }) + label
                    val actionPending = PendingIntent.getBroadcast(
                        context, uniqueKey.hashCode(), actionIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    builder.addAction(0, label, actionPending)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse actions: ${e.message}")
            }
        } else {
            Log.w(TAG, "No actions found in data payload")
        }

        val notifId = eventId.hashCode().and(0x7FFFFFFF) % 100000
        Log.d(TAG, "Showing notification with id=$notifId")
        manager.notify(notifId, builder.build())
        Log.d(TAG, "Notification shown successfully")
    }
}