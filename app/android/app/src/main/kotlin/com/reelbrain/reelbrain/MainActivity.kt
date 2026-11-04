package com.reelbrain.reelbrain

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Backend.init(applicationContext)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reelbrain/downloader").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // download(url) -> {path, duration_s, size_bytes}; error code is a DownloadErrors code.
                    "download" -> {
                        val url = call.argument<String>("url")
                        if (url == null) return@setMethodCallHandler result.error("BAD_ARGS", "url required", null)
                        background(result) { Downloader.download(applicationContext, url).toMap() }
                    }
                    "enqueue" -> result.success(
                        Saves.enqueue(
                            applicationContext, call.argument<String>("url")!!, call.argument<String>("space") ?: "me",
                            hint = call.argument<String>("hint"),
                        ),
                    )
                    "saves" -> result.success(Saves.all(applicationContext).toString())
                    "retryWaiting" -> result.success(Saves.retryWaiting(applicationContext))
                    // This install's Firebase installation ID: FCM's send target once registered.
                    "fid" -> background(result) {
                        com.google.android.gms.tasks.Tasks.await(com.google.firebase.installations.FirebaseInstallations.getInstance().id)
                    }
                    "setBackendUrl" -> {
                        Backend.setUrl(applicationContext, call.argument<String>("url")!!)
                        result.success(null)
                    }
                    // api(method, path, body?) -> response JSON text, as the signed-in user.
                    "api" -> background(result) {
                        Backend.call(call.argument<String>("method")!!, call.argument<String>("path")!!, call.argument<String>("body"))
                    }
                    "openUrl" -> {
                        startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(call.argument<String>("url"))))
                        result.success(null)
                    }
                    // shareImage(bytes, text): an achievement or recap card through the share sheet.
                    "shareImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) return@setMethodCallHandler result.error("BAD_ARGS", "bytes required", null)
                        val dir = java.io.File(cacheDir, "share").apply { mkdirs() }
                        val file = java.io.File(dir, "realbrain.png").apply { writeBytes(bytes) }
                        val uri = androidx.core.content.FileProvider.getUriForFile(this@MainActivity, "$packageName.files", file)
                        val send = Intent(Intent.ACTION_SEND).setType("image/png")
                            .putExtra(Intent.EXTRA_STREAM, uri)
                            .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        startActivity(Intent.createChooser(send, null))
                        result.success(null)
                    }
                    "share" -> {
                        val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                            .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                        startActivity(Intent.createChooser(send, null))
                        result.success(null)
                    }
                    // The invite link that opened the app, if any (later ones arrive as "link" calls).
                    "initialLink" -> result.success(intent?.data?.toString())
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.let { channel?.invokeMethod("link", it.toString()) }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        thread {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (e: DownloadError) {
                runOnUiThread { result.error(e.code, e.message, null) }
            } catch (e: NotSignedIn) {
                runOnUiThread { result.error("NOT_SIGNED_IN", e.message, null) }
            } catch (e: Rejected) {
                runOnUiThread { result.error("HTTP_${e.code}", e.message, null) }
            } catch (e: IOException) {
                runOnUiThread { result.error("BACKEND_UNREACHABLE", e.message, null) }
            } catch (e: Exception) {
                // Anything else is reported to Flutter too: an uncaught throw here kills the app.
                runOnUiThread { result.error("FAILED", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }
}
