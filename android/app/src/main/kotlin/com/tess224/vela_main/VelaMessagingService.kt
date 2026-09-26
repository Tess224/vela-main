package com.tess224.vela_main

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import android.os.Build
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

        if (type == "context_confirm" || type == "ambient_nudge" || type == "ambient_checkin") {
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
        // Same key the action receiver uses to dismiss the notification. Check-ins
        // carry neither an event_id nor a nudge_id, so they need their own key.
        val notifKey = listOf(data["event_id"], data["nudge_id"], data["checkin_id"])
            .firstOrNull { !it.isNullOrEmpty() } ?: ""

        Log.d(TAG, "showWithActions — title=$title body=$body eventId=$eventId")

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            channelId,
            "Vela Alerts",
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.description = "Health deviation alerts from Vela"
        manager.createNotificationChannel(channel)

        // Tap intent — opens the app with all FCM data as extras
        val tapIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (tapIntent != null) {
            for ((k, v) in data) {
                tapIntent.putExtra(k, v)
            }
            tapIntent.putExtra("from_notification", "true")
            tapIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val tapPending = PendingIntent.getActivity(
            context, notifKey.hashCode(), tapIntent,
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
                    actionIntent.putExtra("event_id", data["event_id"] ?: "")
                    actionIntent.putExtra("nudge_id", data["nudge_id"] ?: "")
                    actionIntent.putExtra("checkin_id", data["checkin_id"] ?: "")
                    actionIntent.putExtra("type", data["type"] ?: "")
                    actionIntent.putExtra("response_token", data["response_token"] ?: "")

                    val uniqueKey = notifKey + label
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

        // More than three options arrive as reply_choices (Android shows at most
        // three buttons). Offer them as reply chips; typed text is not allowed.
        val replyJson = data["reply_choices"]
        if (actionsJson.isNullOrEmpty() && !replyJson.isNullOrEmpty()) {
            try {
                val arr = JSONArray(replyJson)
                val choices = Array<CharSequence>(arr.length()) { arr.getString(it) }
                val remoteInput = RemoteInput.Builder(NotificationActionReceiver.KEY_REPLY)
                    .setLabel("Answer")
                    .setChoices(choices)
                    .setAllowFreeFormInput(false)
                    .build()
                val replyIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                    action = "com.tess224.vela_main.NOTIFICATION_ACTION"
                    putExtra("event_id", data["event_id"] ?: "")
                    putExtra("nudge_id", data["nudge_id"] ?: "")
                    putExtra("checkin_id", data["checkin_id"] ?: "")
                    putExtra("type", data["type"] ?: "")
                    putExtra("response_token", data["response_token"] ?: "")
                    putExtra("reply_choices", replyJson)
                }
                // RemoteInput writes the chosen reply into the intent, so it must be mutable.
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
                val replyPending = PendingIntent.getBroadcast(
                    context, (notifKey + ":reply").hashCode(), replyIntent, flags
                )
                val replyAction = NotificationCompat.Action.Builder(0, "Answer", replyPending)
                    .addRemoteInput(remoteInput)
                    .setAllowGeneratedReplies(false)
                    .build()
                builder.addAction(replyAction)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to build reply choices: ${e.message}")
            }
        }

        val notifId = notifKey.hashCode().and(0x7FFFFFFF) % 100000
        Log.d(TAG, "Showing notification with id=$notifId")
        manager.notify(notifId, builder.build())
        Log.d(TAG, "Notification shown successfully")
    }
}