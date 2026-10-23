package com.reelbrain.reelbrain

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

/**
 * Share target behind the "Reelbrain · Me" and "Reelbrain · Home" aliases.
 * Queues the shared URL with its space and finishes without starting Flutter.
 */
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val space = if (componentName.className.endsWith("ShareHome")) "home" else "me"
        val url = ShareText.extractUrl(intent?.getStringExtra(Intent.EXTRA_TEXT))
        if (url == null) {
            Log.w(TAG, "share to $space had no link")
            Toast.makeText(this, R.string.share_no_link, Toast.LENGTH_SHORT).show()
        } else {
            enqueue(url, space)
            Log.i(TAG, "queued space=$space url=$url")
        }
        finish()
    }

    // ponytail: SharedPreferences JSON list; P0-03's worker drains it. Move to WorkManager input/Room if it grows.
    private fun enqueue(url: String, space: String) {
        val prefs = getSharedPreferences(QUEUE, MODE_PRIVATE)
        val list = JSONArray(prefs.getString(KEY, "[]"))
        list.put(JSONObject().put("url", url).put("space", space).put("at", System.currentTimeMillis()))
        prefs.edit().putString(KEY, list.toString()).apply()
    }

    companion object {
        const val TAG = "Reelbrain"
        const val QUEUE = "share_queue"
        const val KEY = "pending"
    }
}

object ShareText {
    private val url = Regex("""https?://[^\s<>"]+""")

    /** First http(s) link in shared text, minus trailing punctuation from the caption. */
    fun extractUrl(text: String?): String? =
        text?.let { url.find(it)?.value?.trimEnd('.', ',', '!', '?', ')', ']', '\'', '…') }
}
