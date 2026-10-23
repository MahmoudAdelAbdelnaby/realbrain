package com.reelbrain.reelbrain

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.TimeUnit

/** Android's optString turns JSON null into "null"; this doesn't. */
fun JSONObject.str(key: String): String? = if (isNull(key)) null else optString(key).ifEmpty { null }

/** Local record of every share, newest first. The phone-side truth until the backend owns saves. */
object Saves {
    private const val PREFS = "saves"
    private const val KEY = "list"
    private const val MAX = 100

    @Synchronized
    fun all(ctx: Context): JSONArray =
        JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))

    @Synchronized
    fun get(ctx: Context, id: String): JSONObject? {
        val list = all(ctx)
        for (i in 0 until list.length()) if (list.getJSONObject(i).optString("id") == id) return list.getJSONObject(i)
        return null
    }

    @Synchronized
    fun upsert(ctx: Context, id: String, fields: Map<String, Any?>) {
        val list = all(ctx)
        var entry: JSONObject? = null
        for (i in 0 until list.length()) if (list.getJSONObject(i).optString("id") == id) entry = list.getJSONObject(i)
        val next = JSONArray()
        if (entry == null) {
            entry = JSONObject().put("id", id)
            next.put(entry)
        }
        fields.forEach { (k, v) -> entry.put(k, v ?: JSONObject.NULL) }
        for (i in 0 until list.length()) if (next.length() < MAX) next.put(list.get(i))
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, next.toString()).apply()
    }

    /** Creates the save and starts its background download + upload. */
    fun enqueue(ctx: Context, url: String, space: String, sharedText: String? = null): String {
        val id = UUID.randomUUID().toString()
        upsert(
            ctx, id,
            mapOf("url" to url, "space" to space, "shared_text" to sharedText, "status" to "queued", "at" to System.currentTimeMillis()),
        )
        val work = OneTimeWorkRequestBuilder<SaveWorker>()
            .setInputData(workDataOf("id" to id))
            .setConstraints(Constraints(requiredNetworkType = NetworkType.CONNECTED))
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.SECONDS)
            .build()
        // ponytail: plain (not expedited) work; starts in seconds on an idle phone. Expedite if saves feel slow.
        WorkManager.getInstance(ctx).enqueue(work)
        return id
    }
}

/**
 * Runs outside the share sheet, so closing it doesn't cancel anything.
 * download on the phone -> (backend configured) create save -> PUT video -> /uploaded.
 * Phone can't download -> /no-video, and the backend's fallback chain takes over.
 */
class SaveWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    private val ctx get() = applicationContext

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val id = inputData.getString("id") ?: return@withContext Result.failure()
        val save = Saves.get(ctx, id) ?: return@withContext Result.failure()
        val url = save.getString("url")
        val lastTry = runAttemptCount >= 2

        // 1. Download, unless an earlier attempt already did.
        var file = save.str("path")?.let(::File)?.takeIf { it.exists() }
        if (file == null) {
            Saves.upsert(ctx, id, mapOf("status" to "downloading", "attempt" to runAttemptCount + 1))
            val started = System.currentTimeMillis()
            try {
                val d = Downloader.download(ctx, url)
                Saves.upsert(ctx, id, d.toMap() + mapOf("status" to "downloaded", "download_ms" to System.currentTimeMillis() - started, "error" to null))
                Log.i(ShareActivity.TAG, "downloaded id=$id ${d.sizeBytes}B ${d.durationS}s in ${System.currentTimeMillis() - started}ms")
                file = File(d.path)
            } catch (e: DownloadError) {
                Log.w(ShareActivity.TAG, "download id=$id failed ${e.code}: ${e.message}")
                val retry = DownloadErrors.isTransient(e.code) && !lastTry
                Saves.upsert(ctx, id, mapOf("status" to if (retry) "queued" else "failed", "error" to e.code, "error_detail" to e.message))
                if (retry) return@withContext Result.retry()
                return@withContext sendWithoutVideo(id, save, e.code)
            }
        }
        if (!Backend.configured) return@withContext Result.success()

        // 2. Hand the video to the backend.
        try {
            Saves.upsert(ctx, id, mapOf("status" to "uploading"))
            val saved = Saves.get(ctx, id)!!
            val (saveId, uploadUrl) = Backend.createSave(
                ctx, url, save.getString("space"),
                saved.str("caption") ?: save.str("shared_text"), saved.str("creator"),
            )
            Backend.upload(uploadUrl, file!!)
            Backend.uploaded(ctx, saveId)
            file!!.delete()
            Saves.upsert(ctx, id, mapOf("status" to "uploaded", "save_id" to saveId, "path" to null, "error" to null))
            Log.i(ShareActivity.TAG, "uploaded id=$id save=$saveId")
            Result.success()
        } catch (e: Exception) {
            Log.w(ShareActivity.TAG, "upload id=$id failed: ${e.message}")
            Saves.upsert(ctx, id, mapOf("status" to if (lastTry) "upload_failed" else "downloaded", "error" to "UPLOAD", "error_detail" to e.message))
            if (lastTry) Result.failure() else Result.retry()
        }
    }

    private fun sendWithoutVideo(id: String, save: JSONObject, reason: String): Result {
        if (!Backend.configured) return Result.failure()
        return try {
            val (saveId, _) = Backend.createSave(ctx, save.getString("url"), save.getString("space"), save.str("shared_text"), null)
            Backend.noVideo(ctx, saveId, reason)
            Saves.upsert(ctx, id, mapOf("status" to "sent_without_video", "save_id" to saveId))
            Result.success()
        } catch (e: IOException) {
            Log.w(ShareActivity.TAG, "no-video id=$id failed: ${e.message}")
            Result.retry()
        }
    }
}
