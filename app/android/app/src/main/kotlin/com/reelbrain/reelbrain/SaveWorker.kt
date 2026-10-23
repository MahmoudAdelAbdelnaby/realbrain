package com.reelbrain.reelbrain

import android.content.Context
import android.util.Log
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
import java.util.UUID

/** Local record of every share, newest first. The phone-side truth until the backend owns saves. */
object Saves {
    private const val PREFS = "saves"
    private const val KEY = "list"
    private const val MAX = 100

    @Synchronized
    fun all(ctx: Context): JSONArray =
        JSONArray(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "[]"))

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

    /** Creates the save and starts its background download. */
    fun enqueue(ctx: Context, url: String, space: String): String {
        val id = UUID.randomUUID().toString()
        upsert(ctx, id, mapOf("url" to url, "space" to space, "status" to "queued", "at" to System.currentTimeMillis()))
        val work = OneTimeWorkRequestBuilder<SaveWorker>()
            .setInputData(workDataOf("id" to id, "url" to url))
            .setConstraints(Constraints(requiredNetworkType = NetworkType.CONNECTED))
            .build()
        // ponytail: plain (not expedited) work; starts in seconds on an idle phone. Expedite if saves feel slow.
        WorkManager.getInstance(ctx).enqueue(work)
        return id
    }
}

/** Runs outside the share sheet, so closing it doesn't cancel the download. */
class SaveWorker(ctx: Context, params: WorkerParameters) : CoroutineWorker(ctx, params) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val id = inputData.getString("id") ?: return@withContext Result.failure()
        val url = inputData.getString("url") ?: return@withContext Result.failure()
        Saves.upsert(applicationContext, id, mapOf("status" to "downloading", "attempt" to runAttemptCount + 1))
        val started = System.currentTimeMillis()
        try {
            val d = Downloader.download(applicationContext, url)
            Saves.upsert(
                applicationContext, id,
                d.toMap() + mapOf("status" to "downloaded", "download_ms" to System.currentTimeMillis() - started, "error" to null),
            )
            Log.i(ShareActivity.TAG, "downloaded id=$id ${d.sizeBytes}B ${d.durationS}s in ${System.currentTimeMillis() - started}ms")
            Result.success()
        } catch (e: DownloadError) {
            val retry = DownloadErrors.isTransient(e.code) && runAttemptCount < 2
            Saves.upsert(applicationContext, id, mapOf("status" to if (retry) "queued" else "failed", "error" to e.code, "error_detail" to e.message))
            Log.w(ShareActivity.TAG, "download id=$id failed ${e.code}: ${e.message}")
            if (retry) Result.retry() else Result.failure()
        }
    }
}
