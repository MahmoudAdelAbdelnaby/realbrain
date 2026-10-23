package com.reelbrain.reelbrain

import android.content.Context
import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

/** Not signed in yet: the save waits on the phone and is sent after sign-in. */
class NotSignedIn : IOException("not signed in")

/** The backend answered with an error that retrying won't fix (4xx). */
class Rejected(val code: Int, message: String) : IOException(message)

/**
 * Phone -> backend calls from the Backend contract. API URL from android/local.properties
 * (reelbrain.apiUrl); Firebase from app/google-services.json, signed in as the Google user the
 * Flutter app signed in (same default FirebaseApp in this process).
 */
object Backend {
    val configured get() = BuildConfig.API_URL.isNotEmpty()

    private fun token(): String {
        val user = FirebaseAuth.getInstance().currentUser ?: throw NotSignedIn()
        return Tasks.await(user.getIdToken(false), 30, TimeUnit.SECONDS).token ?: throw NotSignedIn()
    }

    /** POST /v1/saves -> (save_id, upload_url). */
    fun createSave(url: String, space: String, caption: String?, creator: String?): Pair<String, String> {
        val body = JSONObject().put("source_url", url).put("space_id", space)
        caption?.takeIf { it.isNotBlank() }?.let { body.put("caption", it.take(5000)) }
        creator?.takeIf { it.isNotBlank() }?.let { body.put("creator", it.take(200)) }
        val res = JSONObject(call("POST", "/v1/saves", body.toString()))
        return res.getString("save_id") to res.getString("upload_url")
    }

    fun uploaded(saveId: String) = call("POST", "/v1/saves/$saveId/uploaded", "{}")

    fun noVideo(saveId: String, reason: String) =
        call("POST", "/v1/saves/$saveId/no-video", JSONObject().put("reason", reason).toString())

    /** PUT to the upload URL (no auth header: the URL is the credential). */
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
            val code = conn.responseCode
            if (code in 400..499) throw Rejected(code, "upload HTTP $code")
            if (code !in 200..299) throw IOException("upload HTTP $code")
        } finally {
            conn.disconnect()
        }
    }

    /** Authenticated JSON call; also used by the Flutter screens through the platform channel. */
    fun call(method: String, path: String, body: String?): String {
        if (!configured) throw IOException("no backend configured (reelbrain.apiUrl)")
        val conn = URL(BuildConfig.API_URL.trimEnd('/') + path).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = method
            conn.connectTimeout = 20_000
            conn.readTimeout = 30_000
            conn.setRequestProperty("Authorization", "Bearer ${token()}")
            if (body != null) {
                conn.doOutput = true
                conn.setRequestProperty("Content-Type", "application/json")
                conn.outputStream.use { it.write(body.toByteArray()) }
            }
            val code = conn.responseCode
            val text = (if (code < 400) conn.inputStream else conn.errorStream)?.bufferedReader()?.readText().orEmpty()
            if (code in 400..499) throw Rejected(code, "$method $path HTTP $code: ${text.take(200)}")
            if (code !in 200..299) throw IOException("$method $path HTTP $code: ${text.take(200)}")
            return text
        } finally {
            conn.disconnect()
        }
    }
}
