package com.reelbrain.reelbrain

import android.content.Context
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.OutOfQuotaPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runInterruptible
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
    /** [hint]: Create's "What is this?" (a section id), sent with the save. */
    fun enqueue(ctx: Context, url: String, space: String, sharedText: String? = null, hint: String? = null): String {
        val id = UUID.randomUUID().toString()
        upsert(
            ctx, id,
            mapOf(
                "url" to url, "space" to space, "shared_text" to sharedText, "hint" to hint,
                "status" to "queued", "at" to System.currentTimeMillis(),
            ),
        )
        start(ctx, id, ExistingWorkPolicy.KEEP)
        return id
    }

    private fun start(ctx: Context, id: String, policy: ExistingWorkPolicy) {
        val work = OneTimeWorkRequestBuilder<SaveWorker>()
            .setInputData(workDataOf("id" to id))
            .setConstraints(Constraints(requiredNetworkType = NetworkType.CONNECTED))
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.SECONDS)
            // Expedited: starts now, even with the app closed. Plain work was deferred until the app reopened.
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .build()
        WorkManager.getInstance(ctx).enqueueUniqueWork("save-$id", policy, work)
    }

    /** Right after sign-in (or a backend change): send waiting saves now instead of at their next backoff. */
    fun retryWaiting(ctx: Context): Int {
        val list = all(ctx)
        var n = 0
        for (i in 0 until list.length()) {
            val save = list.getJSONObject(i)
            if (save.optString("status") == "waiting") {
                start(ctx, save.getString("id"), ExistingWorkPolicy.REPLACE)
                n++
            }
        }
        return n
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
        Backend.init(ctx)
        val url = save.getString("url")
        val lastTry = runAttemptCount >= 2

        // 1. Download, unless an earlier attempt already did.
        var file = save.str("path")?.let(::File)?.takeIf { it.exists() }
        if (file == null) {
            Saves.upsert(ctx, id, mapOf("status" to "downloading", "attempt" to runAttemptCount + 1))
            val started = System.currentTimeMillis()
            try {
                val d = runInterruptible { Downloader.download(ctx, url, id) }
                Saves.upsert(
                    ctx, id,
                    d.toMap() + mapOf("status" to "downloaded", "download_ms" to System.currentTimeMillis() - started, "error" to null, "error_detail" to null),
                )
                Log.i(ShareActivity.TAG, "downloaded id=$id ${d.sizeBytes}B ${d.durationS}s in ${System.currentTimeMillis() - started}ms")
                file = File(d.path)
            } catch (e: CancellationException) {
                Downloader.stop(id) // the worker was stopped: don't leave yt-dlp racing the retry
                throw e
            } catch (e: DownloadError) {
                Log.w(ShareActivity.TAG, "download id=$id failed ${e.code}: ${e.message}")
                val retry = DownloadErrors.isTransient(e.code) && !lastTry
                Saves.upsert(ctx, id, mapOf("status" to if (retry) "queued" else "failed", "error" to e.code, "error_detail" to e.message))
                if (retry) return@withContext Result.retry()
                return@withContext sendWithoutVideo(id, save, e.code)
            }
        }
        Downloader.updateIfStale(ctx)
        if (!Backend.configured) return@withContext Result.success()

        // 2. Hand the video to the backend. Not signed in, or the backend unreachable (PC off, away
        //    from home): keep the video and retry with backoff, so nothing shared is ever lost.
        try {
            Saves.upsert(ctx, id, mapOf("status" to "uploading"))
            val saved = Saves.get(ctx, id)!!
            val (saveId, uploadUrl, fresh) = Backend.createSave(
                url, save.getString("space"), saved.str("caption") ?: save.str("shared_text"), saved.str("creator"), id,
                save.str("hint"),
            )
            // A retry after the backend already has the video: nothing left to send.
            if (fresh) {
                Backend.upload(uploadUrl, file!!)
                Backend.uploaded(saveId)
            }
            file!!.delete()
            Saves.upsert(ctx, id, mapOf("status" to "uploaded", "save_id" to saveId, "path" to null, "error" to null, "error_detail" to null))
            Log.i(ShareActivity.TAG, "uploaded id=$id save=$saveId")
            Result.success()
        } catch (e: Rejected) {
            Log.w(ShareActivity.TAG, "upload id=$id rejected: ${e.message}")
            Saves.upsert(ctx, id, mapOf("status" to "upload_failed", "error" to "HTTP_${e.code}", "error_detail" to e.message))
            Result.failure()
        } catch (e: IOException) {
            val why = if (e is NotSignedIn) "NOT_SIGNED_IN" else "BACKEND_UNREACHABLE"
            Log.w(ShareActivity.TAG, "upload id=$id waiting ($why): ${e.message}")
            Saves.upsert(ctx, id, mapOf("status" to "waiting", "error" to why, "error_detail" to e.message))
            Result.retry()
        }
    }

    /** Needed below Android 12, where expedited work runs as a foreground service. */
    override suspend fun getForegroundInfo(): ForegroundInfo {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(NotificationChannel("saves", "Saving reels", NotificationManager.IMPORTANCE_LOW))
        }
        val n = NotificationCompat.Builder(ctx, "saves")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Saving reel")
            .setOngoing(true)
            .build()
        return if (Build.VERSION.SDK_INT >= 29) ForegroundInfo(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC) else ForegroundInfo(1, n)
    }

    private fun sendWithoutVideo(id: String, save: JSONObject, reason: String): Result {
        if (!Backend.configured) return Result.failure()
        return try {
            val (saveId, _, fresh) = Backend.createSave(save.getString("url"), save.getString("space"), save.str("shared_text"), null, id, save.str("hint"))
            if (fresh) Backend.noVideo(saveId, reason)
            Saves.upsert(ctx, id, mapOf("status" to "sent_without_video", "save_id" to saveId))
            Result.success()
        } catch (e: Rejected) {
            Log.w(ShareActivity.TAG, "no-video id=$id rejected: ${e.message}")
            Result.failure()
        } catch (e: IOException) {
            Log.w(ShareActivity.TAG, "no-video id=$id failed: ${e.message}")
            Result.retry()
        }
    }
}
