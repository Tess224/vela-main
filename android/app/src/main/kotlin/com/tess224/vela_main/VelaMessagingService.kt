package com.tess224.vela_main

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONArray

class VelaMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: ""

        if (type == "context_confirm") {
            // Build notification with action buttons
            showWithActions(data)
        } else {
            // Let Flutter handle all other types
            super.onMessageReceived(message)
        }
    }

    private fun showWithActions(data: Map<String, String>) {
        val channelId = "vela_alerts"
        val title = data["title"] ?: "Vela"
        val body = data["body"] ?: ""
        val eventId = data["event_id"] ?: ""

        // Create notification channel
        val channel = NotificationChannel(
            channelId,
            "Vela Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Health deviation alerts from Vela"
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)

        // Tap intent — opens the app
        val tapIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            putExtra("type", "context_confirm")
            putExtra("event_id", eventId)
            for ((k, v) in data) putExtra(k, v)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPending = PendingIntent.getActivity(
            this, eventId.hashCode(), tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Build notification
        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(tapPending)

        // Parse and add action buttons
        val actionsJson = data["actions"]
        if (!actionsJson.isNullOrEmpty()) {
            try {
                val arr = JSONArray(actionsJson)
                for (i in 0 until arr.length()) {
                    val label = arr.getString(i)

                    val actionIntent = Intent(this, NotificationActionReceiver::class.java).apply {
                        action = "com.tess224.vela_main.NOTIFICATION_ACTION"
                        putExtra("action_id", label)
                        putExtra("event_id", eventId)
                    }
                    val actionPending = PendingIntent.getBroadcast(
                        this, (eventId + label).hashCode(), actionIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    builder.addAction(0, label, actionPending)
                }
            } catch (_: Exception) {}
        }

        val notifId = eventId.hashCode().and(0x7FFFFFFF) % 100000
        manager.notify(notifId, builder.build())
    }
}
