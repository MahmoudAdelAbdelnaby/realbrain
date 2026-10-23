package com.reelbrain.reelbrain

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Toast

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
            val id = Saves.enqueue(this, url, space)
            Log.i(TAG, "queued id=$id space=$space url=$url")
        }
        finish()
    }

    companion object {
        const val TAG = "Reelbrain"
    }
}

object ShareText {
    private val url = Regex("""https?://[^\s<>"]+""")

    /** First http(s) link in shared text, minus trailing punctuation from the caption. */
    fun extractUrl(text: String?): String? =
        text?.let { url.find(it)?.value?.trimEnd('.', ',', '!', '?', ')', ']', '\'', '…') }
}
