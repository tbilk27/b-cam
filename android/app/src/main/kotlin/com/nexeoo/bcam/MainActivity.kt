package com.nexeoo.bcam

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.URLEncoder

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.nexeoo.bcam/deeplink"
    private var pendingDeepLink: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Impede que a tela do dispositivo apague ou bloqueie enquanto o app b-cam estiver aberto
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

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

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialDeepLink" -> {
                    val link = pendingDeepLink
                    pendingDeepLink = null
                    result.success(link)
                }
                "shareLogViaWhatsApp" -> {
                    val filePath = call.argument<String>("filePath")
                    val rawPhone = call.argument<String>("phone") ?: "5547988366727"
                    val message = call.argument<String>("message") ?: "Arquivo de log b-cam"

                    try {
                        val digits = rawPhone.replace(Regex("[^0-9]"), "")
                        val phone = if (digits.startsWith("55")) digits else "55$digits"
                        val jid = "$phone@s.whatsapp.net"
                        val file = filePath?.let { File(it) }

                        val isNormalInstalled = isAppInstalled("com.whatsapp")
                        val isBusinessInstalled = isAppInstalled("com.whatsapp.w4b")
                        val targetPackage = when {
                            isNormalInstalled -> "com.whatsapp"
                            isBusinessInstalled -> "com.whatsapp.w4b"
                            else -> null
                        }

                        if (file != null && file.exists()) {
                            val fileUri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )

                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_STREAM, fileUri)
                                putExtra(Intent.EXTRA_TEXT, message)
                                putExtra("jid", jid)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                if (targetPackage != null) {
                                    setPackage(targetPackage)
                                }
                            }

                            if (targetPackage != null) {
                                grantUriPermission(targetPackage, fileUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }

                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                val chooser = Intent.createChooser(intent, "Enviar log via WhatsApp para $phone").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(chooser)
                                result.success(true)
                            }
                        } else {
                            val uri = Uri.parse("https://api.whatsapp.com/send?phone=$phone&text=${URLEncoder.encode(message, "UTF-8")}")
                            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                if (targetPackage != null) {
                                    setPackage(targetPackage)
                                }
                            }
                            startActivity(intent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("WHATSAPP_SEND_ERROR", e.localizedMessage, null)
                    }
                }
                "shareReferralViaWhatsApp" -> {
                    val message = call.argument<String>("message")
                        ?: "Olá! Recomendo o b-cam PRO para monitoramento de câmeras de segurança: https://bcam.nexeoo.com"

                    try {
                        val isNormalInstalled = isAppInstalled("com.whatsapp")
                        val isBusinessInstalled = isAppInstalled("com.whatsapp.w4b")
                        val targetPackage = when {
                            isNormalInstalled -> "com.whatsapp"
                            isBusinessInstalled -> "com.whatsapp.w4b"
                            else -> null
                        }

                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, message)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            if (targetPackage != null) {
                                setPackage(targetPackage)
                            }
                        }

                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            val chooser = Intent.createChooser(intent, "Compartilhar b-cam via WhatsApp").apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(chooser)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        pendingDeepLink?.let {
            methodChannel?.invokeMethod("onDeepLink", it)
        }
    }
}
