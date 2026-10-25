package com.reelbrain.reelbrain

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.TextView
import android.widget.Toast

/**
 * Share target behind the "Realbrain · Me" and "Realbrain · Home" aliases.
 * Queues the shared URL with its space, shows the save pill for 1 s over the app it came from,
 * and finishes without starting Flutter.
 */
class ShareActivity : Activity() {
    private val main = Handler(Looper.getMainLooper())
    private val close = Runnable { finish() }
    private lateinit var pill: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The window is only the pill: touches elsewhere go to TikTok/Instagram underneath.
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
        window.setLayout(WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT)
        window.setGravity(Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL)
        window.attributes = window.attributes.apply { y = dp(96) }
        pill = savePill()
        window.setBackgroundDrawable(panel())
        setContentView(pill)
        handle(intent)
    }

    override fun onDestroy() {
        main.removeCallbacks(close)
        super.onDestroy()
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
            finish()
            return
        } else {
            val id = Saves.enqueue(this, url, space, text?.replace(url, "")?.trim()?.ifEmpty { null })
            Log.i(TAG, "queued id=$id space=$space url=$url")
            pill.text = "✓  " + getString(if (space == "home") R.string.share_saving_home else R.string.share_saving_me)
            pill.alpha = 0f
            pill.animate().alpha(1f).setDuration(200).start()
        }
        main.removeCallbacks(close)
        main.postDelayed(close, 1000)
    }

    private val dark get() =
        resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES

    /** Design v4 panel, native: a solid round fill with a lavender edge (no frosted glass).
     * ponytail: no thumbnail yet; the reel's frame only exists after the download, add it then. */
    private fun panel() = GradientDrawable().apply {
        cornerRadius = dp(999).toFloat()
        setColor(if (dark) Color.rgb(0x11, 0x15, 0x28) else Color.WHITE)
        setStroke(dp(1), Color.argb(0x99, 0x9C, 0x8C, 0xFF))
    }

    private fun savePill() = TextView(this).apply {
        setTextColor(if (dark) Color.WHITE else Color.parseColor("#0E1024"))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
        setPadding(dp(20), dp(12), dp(20), dp(12))
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

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
