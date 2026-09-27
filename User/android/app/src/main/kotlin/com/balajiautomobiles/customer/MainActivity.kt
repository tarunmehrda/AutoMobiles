package com.balajiautomobiles.customer

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Adds one thing to the stock activity: writing a file into the phone's own
 * Downloads folder.
 *
 * Flutter cannot reach public storage on its own. On Android 10 and up this
 * goes through MediaStore, which needs no permission at all and puts the file
 * where the Downloads app and every file manager will find it. Below that the
 * classic public directory still works.
 */
class MainActivity : FlutterActivity() {
    private val channel = "garagepro/downloads"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createUpdatesChannel()
    }

    /**
     * The channel pushed updates from the workshop land in - "your car is
     * ready", "booking confirmed" - chosen by the sender as
     * `customer_updates_v1` (supabase/functions/notify-garage/index.ts).
     *
     * HIGH, so it pops up over whatever is on screen and rings. A channel's
     * sound and importance are fixed once created; changing them means a new
     * id (`_v2`), because re-creating `_v1` with new settings does nothing on
     * a phone that already has it.
     */
    private fun createUpdatesChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val attrs = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()
        val updates = NotificationChannel(
            "customer_updates_v1",
            "Updates from your workshop",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Bookings confirmed or moved, your vehicle ready, payments received."
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 200, 120, 200)
            setSound(
                Uri.parse("android.resource://$packageName/${R.raw.alert_general}"),
                attrs,
            )
        }
        manager.createNotificationChannel(updates)
    }

    /**
     * The chime for an update the app shows while it is open.
     *
     * A customer is not watching this screen - they are at work, or
     * driving, or waiting - so an update that slides in silently is one
     * they find later by accident. The same two WAVs the workshop console
     * uses for the same events, so the two apps sound like one product.
     *
     * Played on the notification stream, so it follows the phone's ring
     * profile: a handset that has been silenced stays silent.
     */
    private var chime: MediaPlayer? = null

    private fun playAlertSound(kind: String?) {
        val res = if (kind == "booking") R.raw.alert_booking else R.raw.alert_general
        // One at a time: two updates landing together should chime once.
        chime?.release()
        chime = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build(),
            )
            setOnCompletionListener { it.release(); if (chime === it) chime = null }
            try {
                resources.openRawResourceFd(res).use {
                    setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
                prepare()
                start()
            } catch (e: Exception) {
                // Never worth a crash on a customer's phone; the banner
                // still shows.
                release()
                chime = null
            }
        }
    }

    override fun onDestroy() {
        chime?.release()
        chime = null
        super.onDestroy()
    }

    /**
     * Whether Android already lets this app run in the background without
     * battery restrictions - what a pushed update needs to arrive while the
     * app is shut on phones that stop idle apps hard (Xiaomi, Vivo, Oppo).
     */
    private fun runsUnrestricted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val power = getSystemService(PowerManager::class.java) ?: return true
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Android's own one-tap dialog, "Let the app always run in the
     * background?", instead of sending a customer into Settings -> Apps ->
     * Battery, which nobody does. Falls back to the list screen on the odd
     * phone that has no dialog.
     */
    private fun askToRunUnrestricted() {
        if (runsUnrestricted()) return
        try {
            startActivity(
                Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:$packageName"),
                ),
            )
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "garagepro/power")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "runsUnrestricted" -> result.success(runsUnrestricted())
                    "askToRunUnrestricted" -> {
                        askToRunUnrestricted()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "garagepro/alerts")
            .setMethodCallHandler { call, result ->
                if (call.method == "chime") {
                    playAlertSound(call.argument<String>("kind"))
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                val mime = call.argument<String>("mime") ?: "application/octet-stream"
                if (name == null || bytes == null) {
                    result.error("bad_args", "name and bytes are required", null)
                    return@setMethodCallHandler
                }
                try {
                    result.success(save(name, bytes, mime))
                } catch (e: Exception) {
                    result.error("write_failed", e.message, null)
                }
            }
    }

    private fun save(name: String, bytes: ByteArray, mime: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
            ) ?: throw IllegalStateException("Downloads is not writable")

            resolver.openOutputStream(uri).use { out ->
                requireNotNull(out).write(bytes)
            }
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return "Downloads/$name"
        }

        @Suppress("DEPRECATION")
        val dir = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, name)
        file.writeBytes(bytes)
        return file.absolutePath
    }
}
