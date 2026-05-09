package com.tess224.vela_main

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val actionId = intent.getStringExtra("action_id") ?: return
        val eventId = intent.getStringExtra("event_id") ?: return

        // Dismiss the notification
        val notifId = eventId.hashCode().and(0x7FFFFFFF) % 100000
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(notifId)

        // Store the response for Flutter to pick up on next launch
        val prefs = context.getSharedPreferences("vela_action_responses", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("pending_event_id", eventId)
            .putString("pending_action_id", actionId)
            .apply()

        // Launch the app to process the response via Flutter/Supabase
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            putExtra("type", "action_response")
            putExtra("event_id", eventId)
            putExtra("action_id", actionId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        if (launchIntent != null) {
            context.startActivity(launchIntent)
        }
    }
}
