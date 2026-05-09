package com.tess224.vela_main

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONArray

class VelaMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val type = data["type"] ?: ""

        if (type == "context_confirm") {
            showWithActions(data)
        } else {
            super.onMessageReceived(message)
        }
    }

    private fun showWithActions(data: Map<String, String>) {
        val context: Context = this
        val channelId = "vela_alerts"
        val title = data["title"] ?: "Vela"
        val body = data["body"] ?: ""
        val eventId = data["event_id"] ?: ""

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
        if (!actionsJson.isNullOrEmpty()) {
            try {
                val arr = JSONArray(actionsJson)
                for (i in 0 until arr.length()) {
                    val label = arr.getString(i)

                    val actionIntent = Intent(context, NotificationActionReceiver::class.java)
                    actionIntent.action = "com.tess224.vela_main.NOTIFICATION_ACTION"
                    actionIntent.putExtra("action_id", label)
                    actionIntent.putExtra("event_id", eventId)

                    val actionPending = PendingIntent.getBroadcast(
                        context, (eventId + label).hashCode(), actionIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

                    builder.addAction(0, label, actionPending)
                }
            } catch (e: Exception) {
                // Ignore parse errors
            }
        }

        val notifId = eventId.hashCode().and(0x7FFFFFFF) % 100000
        manager.notify(notifId, builder.build())
    }
}