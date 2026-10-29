package com.baleine.wwjing.cookie

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.baleine.wwjing.cookie/share"
    private var channel: MethodChannel? = null
    private var pendingShare: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingShare = shareText(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialShare") {
                    result.success(pendingShare)
                    pendingShare = null
                } else if (call.method == "openInApp") {
                    val url = call.argument<String>("url")
                    val packageName = call.argument<String>("packageName")
                    if (url == null || packageName == null) {
                        result.success(false)
                    } else {
                        result.success(openInApp(url, packageName))
                    }
                } else if (call.method == "openApp") {
                    val packageName = call.argument<String>("packageName")
                    result.success(packageName != null && openApp(packageName))
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        shareText(intent)?.let { text ->
            pendingShare = text
            channel?.invokeMethod("shareReceived", text)
        }
    }

    private fun shareText(source: Intent?): String? {
        if (source?.action != Intent.ACTION_SEND) return null
        return source.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }
    }

    private fun openInApp(url: String, packageName: String): Boolean {
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                setPackage(packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            })
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    private fun openApp(packageName: String): Boolean {
        return try {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                ?: return false
            startActivity(launchIntent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }
}
