package com.reelbrain.reelbrain

import android.content.Context
import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File

data class Download(
    val path: String,
    val durationS: Double?,
    val sizeBytes: Long,
    val caption: String? = null,
    val creator: String? = null,
) {
    fun toMap() = mapOf(
        "path" to path, "duration_s" to durationS, "size_bytes" to sizeBytes, "caption" to caption, "creator" to creator,
    )
}

class DownloadError(val code: String, message: String) : Exception(message)

/** yt-dlp on the phone, so TikTok/Instagram see a residential IP. */
object Downloader {
    private const val UPDATE_EVERY_MS = 24 * 60 * 60 * 1000L
    @Volatile private var ready = false

    @Synchronized
    private fun init(ctx: Context) {
        if (ready) return
        YoutubeDL.getInstance().init(ctx.applicationContext)
        ready = true
    }

    /**
     * TikTok/Instagram extractors break often, so yt-dlp updates itself at most daily.
     * Called after a download, never before: the first share shouldn't wait on it.
     */
    fun updateIfStale(ctx: Context) {
        val prefs = ctx.getSharedPreferences("downloader", Context.MODE_PRIVATE)
        if (!ready || System.currentTimeMillis() - prefs.getLong("updated_at", 0) < UPDATE_EVERY_MS) return
        runCatching { YoutubeDL.getInstance().updateYoutubeDL(ctx.applicationContext, YoutubeDL.UpdateChannel.STABLE) }
            .onSuccess { prefs.edit().putLong("updated_at", System.currentTimeMillis()).apply() }
            .onFailure { Log.w(ShareActivity.TAG, "yt-dlp update failed", it) }
    }

    /** Kills a running yt-dlp, so a stopped worker can't leave one racing its own retry. */
    fun stop(processId: String) {
        YoutubeDL.getInstance().destroyProcessById(processId)
    }

    /** Blocking; call off the main thread. Throws [DownloadError], or InterruptedException when stopped. */
    fun download(ctx: Context, url: String, processId: String = url): Download {
        try {
            init(ctx)
        } catch (e: Exception) {
            throw DownloadError("INIT_FAILED", e.message ?: "init failed")
        }
        val dir = File(ctx.filesDir, "reels").apply { mkdirs() }
        val request = YoutubeDLRequest(url).apply {
            addOption("--no-playlist")
            addOption("--no-mtime")
            // ponytail: single progressive file, no ffmpeg merge; Gemini doesn't need more than 720p.
            addOption("-f", "b[height<=720]/b")
            addOption("-o", "${dir.absolutePath}/%(extractor)s-%(id)s.%(ext)s")
            addOption("--print", "after_move:%(filepath)s|%(duration)s")
            addOption("--write-info-json") // caption and creator for the backend
            addOption("--socket-timeout", "20")
            addOption("--retries", "2")
        }
        val out = try {
            YoutubeDL.getInstance().execute(request, processId).out
        } catch (e: InterruptedException) {
            stop(processId)
            throw e
        } catch (e: YoutubeDL.CanceledException) {
            throw InterruptedException("stopped")
        } catch (e: Exception) {
            val msg = e.message ?: e.toString()
            throw DownloadError(DownloadErrors.classify(msg), msg.takeLast(500))
        }
        val d = DownloadErrors.parsePrint(out)
            ?: throw DownloadError("NO_OUTPUT", "yt-dlp printed no file: ${out.takeLast(300)}")
        val info = File(File(d.path).parentFile, File(d.path).nameWithoutExtension + ".info.json")
        return runCatching {
            val json = org.json.JSONObject(info.readText())
            d.copy(
                caption = json.optString("description").ifBlank { json.optString("title") }.ifBlank { null },
                creator = json.optString("uploader").ifBlank { json.optString("channel") }.ifBlank { null },
            )
        }.getOrDefault(d).also { info.delete() }
    }
}

/** Pure parsing, unit tested without Android. */
object DownloadErrors {
    // Order matters: the first matching rule wins.
    private val rules = listOf(
        "NO_NETWORK" to Regex("(?i)unable to resolve host|network is unreachable|failed to resolve|no address associated|connection refused|getaddrinfo|remote end closed|connection reset|connection aborted|transporterror"),
        "TIMEOUT" to Regex("(?i)timed out|timeout"),
        "LOGIN_REQUIRED" to Regex("(?i)login required|log in|sign in|cookies|private|rate-limit reached|requested content is not available"),
        // yt-dlp couldn't read the page (TikTok "status code 10240", "unable to extract"): the server fallback may.
        "EXTRACTOR" to Regex("""(?i)status code \d+|unable to extract|please report this issue"""),
        "NOT_FOUND" to Regex("(?i)http error 404|video unavailable|this video is unavailable|has been removed|does not exist"),
        "UNSUPPORTED_URL" to Regex("(?i)unsupported url|no video formats|is not a valid url|no video could be found"),
        "BLOCKED" to Regex("(?i)http error 403|forbidden|http error 429|too many requests"),
    )

    /**
     * Classifies on yt-dlp's ERROR lines only: its WARNING lines ("ffmpeg ... does not exist",
     * "impersonation") appear on every run and used to win the match.
     */
    fun classify(message: String): String {
        val errors = message.lines().filter { it.trimStart().startsWith("ERROR") }.joinToString("\n").ifEmpty { message }
        return rules.firstOrNull { (_, re) -> re.containsMatchIn(errors) }?.first ?: "UNKNOWN"
    }

    /** Retrying helps for these; the rest fail the same way again. */
    fun isTransient(code: String) = code == "NO_NETWORK" || code == "TIMEOUT" || code == "BLOCKED"

    /** Last "path|duration" line from `--print after_move:...`. */
    fun parsePrint(out: String): Download? {
        val line = out.lines().lastOrNull { it.contains('|') } ?: return null
        val path = line.substringBeforeLast('|').trim()
        val file = File(path)
        if (path.isEmpty()) return null
        return Download(path, line.substringAfterLast('|').trim().toDoubleOrNull(), if (file.exists()) file.length() else 0L)
    }
}
