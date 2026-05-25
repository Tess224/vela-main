package com.tess224.vela_main

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var notificationExtras: HashMap<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Check launch intent for notification extras
        checkIntentForNotification(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tess224.vela_main/notification")
            .setMethodCallHandler { call, result ->
                if (call.method == "getNotificationExtras") {
                    android.util.Log.d("VelaMessaging", "getNotificationExtras called, extras=$notificationExtras")
                    val extras = notificationExtras
                    notificationExtras = null
                    result.success(extras)
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        android.util.Log.d("VelaMessaging", "onNewIntent fired, from_notification=${intent.getStringExtra("from_notification")}")
        checkIntentForNotification(intent)
    }

    private fun checkIntentForNotification(intent: android.content.Intent?) {
        val extras = intent?.extras ?: return
        if (extras.getString("from_notification") == "true") {
            android.util.Log.d("VelaMessaging", "Notification extras found, type=${extras.getString("type")}")
            val map = HashMap<String, String>()
            for (key in extras.keySet()) {
                val value = extras.getString(key)
                if (value != null) {
                    map[key] = value
                }
            }
            notificationExtras = map
        }
    }
}