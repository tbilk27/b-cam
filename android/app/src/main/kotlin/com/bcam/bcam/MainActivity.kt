package com.bcam.bcam

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bcam.bcam/deeplink"
    private var pendingDeepLink: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.data?.toString()?.let {
            pendingDeepLink = it
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.toString()?.let { url ->
            pendingDeepLink = url
            methodChannel?.invokeMethod("onDeepLink", url)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialDeepLink") {
                val link = pendingDeepLink
                pendingDeepLink = null
                result.success(link)
            } else {
                result.notImplemented()
            }
        }
        pendingDeepLink?.let {
            methodChannel?.invokeMethod("onDeepLink", it)
        }
    }
}
