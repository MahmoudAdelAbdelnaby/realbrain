package com.reelbrain.reelbrain

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reelbrain/downloader").setMethodCallHandler { call, result ->
            when (call.method) {
                // download(url) -> {path, duration_s, size_bytes}; error code is a DownloadErrors code.
                "download" -> {
                    val url = call.argument<String>("url")
                    if (url == null) return@setMethodCallHandler result.error("BAD_ARGS", "url required", null)
                    thread {
                        try {
                            val d = Downloader.download(applicationContext, url)
                            runOnUiThread { result.success(d.toMap()) }
                        } catch (e: DownloadError) {
                            runOnUiThread { result.error(e.code, e.message, null) }
                        }
                    }
                }
                "enqueue" -> result.success(
                    Saves.enqueue(applicationContext, call.argument<String>("url")!!, call.argument<String>("space") ?: "me"),
                )
                "saves" -> result.success(Saves.all(applicationContext).toString())
                else -> result.notImplemented()
            }
        }
    }
}
