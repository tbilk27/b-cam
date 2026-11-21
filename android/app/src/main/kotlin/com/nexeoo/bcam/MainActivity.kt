package com.nexeoo.bcam

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.net.URLEncoder

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.nexeoo.bcam/deeplink"
    private val NOTIFICATION_CHANNEL_ID = "b_cam_surveillance_alerts"
    private var pendingDeepLink: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Impede que a tela do dispositivo apague ou bloqueie enquanto o app b-cam estiver aberto
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        createNotificationChannel()

        intent?.data?.toString()?.let {
            pendingDeepLink = it
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Alertas de Vigilância b-cam"
            val descriptionText = "Notificações prioritárias de eventos de vigilância e IA"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 150, 250)
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
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
                "shareEventViaWhatsApp" -> {
                    val filePath = call.argument<String>("filePath")
                    val message = call.argument<String>("message") ?: "Alerta de Evento b-cam"
                    val rawPhone = call.argument<String>("phone")

                    try {
                        val digits = rawPhone?.replace(Regex("[^0-9]"), "") ?: ""
                        val phone = if (digits.isNotEmpty()) {
                            if (digits.startsWith("55")) digits else "55$digits"
                        } else null

                        val isNormalInstalled = isAppInstalled("com.whatsapp")
                        val isBusinessInstalled = isAppInstalled("com.whatsapp.w4b")
                        val targetPackage = when {
                            isNormalInstalled -> "com.whatsapp"
                            isBusinessInstalled -> "com.whatsapp.w4b"
                            else -> null
                        }

                        val file = filePath?.let { File(it) }

                        if (file != null && file.exists()) {
                            val fileUri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )

                            val mimeType = when {
                                file.name.endsWith(".mp4", ignoreCase = true) -> "video/mp4"
                                file.name.endsWith(".mkv", ignoreCase = true) -> "video/*"
                                file.name.endsWith(".png", ignoreCase = true) -> "image/png"
                                else -> "image/jpeg"
                            }

                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = mimeType
                                putExtra(Intent.EXTRA_STREAM, fileUri)
                                putExtra(Intent.EXTRA_TEXT, message)
                                if (phone != null) {
                                    putExtra("jid", "$phone@s.whatsapp.net")
                                }
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
                            } catch (_: Exception) {
                                val chooser = Intent.createChooser(intent, "Enviar vídeo do evento via WhatsApp").apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(chooser)
                                result.success(true)
                            }
                        } else {
                            if (phone != null && phone.isNotEmpty()) {
                                val uri = Uri.parse("https://api.whatsapp.com/send?phone=$phone&text=${URLEncoder.encode(message, "UTF-8")}")
                                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    if (targetPackage != null) {
                                        setPackage(targetPackage)
                                    }
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
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
                                    val chooser = Intent.createChooser(intent, "Enviar vídeo do evento via WhatsApp").apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(chooser)
                                    result.success(true)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        result.error("WHATSAPP_EVENT_SHARE_ERROR", e.localizedMessage, null)
                    }
                }
                "showSystemNotification" -> {
                    val id = call.argument<Int>("id") ?: System.currentTimeMillis().toInt()
                    val title = call.argument<String>("title") ?: "🚨 Alerta b-cam"
                    val body = call.argument<String>("body") ?: "Movimento detectado"
                    val deepLink = call.argument<String>("deepLink") ?: "bcam://event"

                    try {
                        val notifyIntent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink), this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }

                        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }

                        val pendingIntent = PendingIntent.getActivity(this, id, notifyIntent, pendingIntentFlags)

                        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
                            .setSmallIcon(R.mipmap.ic_launcher)
                            .setContentTitle(title)
                            .setContentText(body)
                            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setCategory(NotificationCompat.CATEGORY_ALARM)
                            .setContentIntent(pendingIntent)
                            .setAutoCancel(true)
                            .setVibrate(longArrayOf(0, 250, 150, 250))

                        with(NotificationManagerCompat.from(this)) {
                            notify(id, builder.build())
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    try {
                        val file = filePath?.let { File(it) }
                        if (file != null && file.exists()) {
                            val apkUri = FileProvider.getUriForFile(
                                this@MainActivity,
                                "${applicationContext.packageName}.fileprovider",
                                file
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("FILE_NOT_FOUND", "Arquivo APK não encontrado em $filePath", null)
                        }
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.localizedMessage, null)
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
