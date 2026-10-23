package com.reelbrain.reelbrain

import android.content.Context
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/**
 * Phone -> backend calls from the Backend contract. Configured from android/local.properties
 * (reelbrain.apiUrl, reelbrain.firebaseApiKey/AppId/ProjectId); without them saves stay on the phone.
 */
object Backend {
    val configured get() = BuildConfig.API_URL.isNotEmpty() && BuildConfig.FIREBASE_APP_ID.isNotEmpty()

    @Synchronized
    private fun auth(ctx: Context): FirebaseAuth {
        val app = FirebaseApp.getApps(ctx).firstOrNull() ?: FirebaseApp.initializeApp(
            ctx.applicationContext,
            FirebaseOptions.Builder()
                .setApiKey(BuildConfig.FIREBASE_API_KEY)
                .setApplicationId(BuildConfig.FIREBASE_APP_ID)
                .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
                .build(),
        )
        return FirebaseAuth.getInstance(app)
    }

    /** Firebase ID token. ponytail: anonymous sign-in for the Phase 0 spike; P1-03 links it to Google sign-in. */
    private fun token(ctx: Context): String {
        val auth = auth(ctx)
        val user = auth.currentUser ?: Tasks.await(auth.signInAnonymously(), 30, TimeUnit.SECONDS).user!!
        return Tasks.await(user.getIdToken(false), 30, TimeUnit.SECONDS).token!!
    }

    /** POST /v1/saves -> (save_id, upload_url). */
    fun createSave(ctx: Context, url: String, space: String, caption: String?, creator: String?): Pair<String, String> {
        val body = JSONObject().put("source_url", url).put("space_id", space)
        caption?.takeIf { it.isNotBlank() }?.let { body.put("caption", it.take(5000)) }
        creator?.takeIf { it.isNotBlank() }?.let { body.put("creator", it.take(200)) }
        val res = JSONObject(call(ctx, "POST", "/v1/saves", body))
        return res.getString("save_id") to res.getString("upload_url")
    }

    fun uploaded(ctx: Context, saveId: String) = call(ctx, "POST", "/v1/saves/$saveId/uploaded", JSONObject())

    fun noVideo(ctx: Context, saveId: String, reason: String) =
        call(ctx, "POST", "/v1/saves/$saveId/no-video", JSONObject().put("reason", reason))

    /** PUT to the signed Storage URL (no auth header: the URL is the credential). */
    fun upload(uploadUrl: String, file: File) {
        val conn = URL(uploadUrl).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "PUT"
            conn.doOutput = true
            conn.setFixedLengthStreamingMode(file.length())
            conn.setRequestProperty("Content-Type", "video/mp4")
            conn.connectTimeout = 20_000
            conn.readTimeout = 120_000
            conn.outputStream.use { out -> file.inputStream().use { it.copyTo(out) } }
            if (conn.responseCode !in 200..299) throw IOException("upload HTTP ${conn.responseCode}")
        } finally {
            conn.disconnect()
        }
    }

    private fun call(ctx: Context, method: String, path: String, body: JSONObject): String {
        val conn = URL(BuildConfig.API_URL.trimEnd('/') + path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = method
            conn.doOutput = true
            conn.connectTimeout = 20_000
            conn.readTimeout = 30_000
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer ${token(ctx)}")
            conn.outputStream.use { it.write(body.toString().toByteArray()) }
            val code = conn.responseCode
            val text = (if (code < 400) conn.inputStream else conn.errorStream)?.bufferedReader()?.readText().orEmpty()
            if (code !in 200..299) throw IOException("$method $path HTTP $code: ${text.take(200)}")
            return text
        } finally {
            conn.disconnect()
        }
    }
}
