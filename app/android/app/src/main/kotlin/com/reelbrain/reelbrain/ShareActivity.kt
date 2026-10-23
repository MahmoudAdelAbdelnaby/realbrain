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
        handle(intent)
    }

    // A second share that lands before this one finished is delivered here, not to a new instance.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        val space = if (intent?.component?.className?.endsWith("ShareHome") ?: componentName.className.endsWith("ShareHome")) "home" else "me"
        val text = intent?.getStringExtra(Intent.EXTRA_TEXT)
        val url = ShareText.extractUrl(text)
        if (url == null) {
            Log.w(TAG, "share to $space had no link")
            Toast.makeText(this, R.string.share_no_link, Toast.LENGTH_SHORT).show()
        } else {
            val id = Saves.enqueue(this, url, space, text?.replace(url, "")?.trim()?.ifEmpty { null })
            Log.i(TAG, "queued id=$id space=$space url=$url")
            // ponytail: plain toast; the styled save pill (thumbnail, check) comes with the design pass.
            Toast.makeText(this, if (space == "home") R.string.share_saving_home else R.string.share_saving_me, Toast.LENGTH_SHORT).show()
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
