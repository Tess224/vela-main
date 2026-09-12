package com.tess224.vela_main

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * On-device queue for notification responses that could not be delivered.
 *
 * The receiver runs with no network guarantee and no Supabase session, so a
 * failed send must not lose the tap. Queued items keep their single-use
 * response token and the time the user actually tapped, so a response drained
 * hours later is still recorded at the moment it happened.
 *
 * Deliberately a private SharedPreferences file rather than the one the
 * shared_preferences plugin owns — that file's encoding is a plugin
 * implementation detail and writing into it from Kotlin is fragile.
 */
object PendingResponseStore {

    private const val PREFS = "vela_pending_responses"
    private const val KEY = "queue"
    private const val MAX_ITEMS = 100

    @Synchronized
    fun enqueue(
        context: Context,
        targetType: String,
        targetId: String,
        response: String,
        responseToken: String,
        tappedAtMillis: Long,
    ) {
        val item = JSONObject().apply {
            put("queue_id", UUID.randomUUID().toString())
            put("target_type", targetType)
            put("target_id", targetId)
            put("response", response)
            put("response_token", responseToken)
            put("tapped_at_ms", tappedAtMillis)
        }

        val queue = load(context)
        queue.put(item)

        // Drop oldest first. An unbounded queue on a device that is offline
        // for weeks is a slow leak, and the oldest taps are the least useful.
        val trimmed = if (queue.length() > MAX_ITEMS) {
            JSONArray().also { out ->
                for (i in (queue.length() - MAX_ITEMS) until queue.length()) {
                    out.put(queue.get(i))
                }
            }
        } else queue

        save(context, trimmed)
    }

    @Synchronized
    fun readAll(context: Context): String = load(context).toString()

    @Synchronized
    fun remove(context: Context, queueIds: Set<String>) {
        if (queueIds.isEmpty()) return
        val queue = load(context)
        val kept = JSONArray()
        for (i in 0 until queue.length()) {
            val item = queue.optJSONObject(i) ?: continue
            if (item.optString("queue_id") !in queueIds) kept.put(item)
        }
        save(context, kept)
    }

    private fun load(context: Context): JSONArray {
        val raw = context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return JSONArray()
        return try {
            JSONArray(raw)
        } catch (e: Exception) {
            JSONArray()
        }
    }

    private fun save(context: Context, queue: JSONArray) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, queue.toString())
            .apply()
    }
}
