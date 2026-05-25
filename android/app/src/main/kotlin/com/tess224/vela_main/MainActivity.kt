package com.tess224.vela_main

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.tess224.vela_main/notification")
            .setMethodCallHandler { call, result ->
                if (call.method == "getNotificationExtras") {
                    val extras = intent.extras
                    if (extras != null && extras.getString("from_notification") == "true") {
                        val map = HashMap<String, String>()
                        for (key in extras.keySet()) {
                            val value = extras.getString(key)
                            if (value != null) {
                                map[key] = value
                            }
                        }
                        intent.removeExtra("from_notification")
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}