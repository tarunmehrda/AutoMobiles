package com.garagepro.garagepro_admin

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
        createAlertChannels()
    }

    /**
     * The channels pushed alerts are filed under - one per kind of alert, so
     * the counter can tell a booking from a payment across the workshop
     * without looking at the phone. Which one a given message lands in is
     * chosen by the sender, in `android.notification.channel_id`; see
     * `supabase/functions/push-alert/index.ts`.
     *
     * ## Why the ids carry a version
     *
     * A channel's sound, importance and vibration are fixed at creation. Once
     * a channel exists on a handset, nothing this app does will change them -
     * only the person holding the phone can, in system settings. Calling
     * `createNotificationChannel` again with new settings is accepted and
     * silently ignored.
     *
     * So the id carries a version. Changing a chime means shipping `..._v2`,
     * which is a new channel and therefore actually takes effect. Editing the
     * sound of `..._v1` in this file would do nothing at all on any handset
     * that has run the app once - the kind of change that looks right in
     * review and is wrong on every phone in the field.
     *
     * Importance is HIGH from the start for the same reason: a workshop that
     * wants a quieter booking alert can turn it down, but a console that
     * shipped silent would need a reinstall to get its sound back.
     */
    private fun createAlertChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        // Played against the notification stream rather than the media one,
        // so these follow the phone's ring profile like every other alert on
        // it - including going quiet when the counter silences the handset.
        val attrs = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        data class Spec(
            val id: String,
            val title: String,
            val blurb: String,
            val sound: Int,
            val pattern: LongArray,
        )

        val specs = listOf(
            Spec(
                "garage_booking_v1",
                "New bookings",
                "A customer asked for a slot. The one alert not to miss.",
                R.raw.alert_booking,
                longArrayOf(0, 260, 140, 260),
            ),
            Spec(
                "garage_payment_v1",
                "Payments",
                "Money received against a job card.",
                R.raw.alert_payment,
                longArrayOf(0, 180),
            ),
            Spec(
                "garage_reminder_v1",
                "Service reminders",
                "A vehicle you are tracking has come due for service.",
                R.raw.alert_reminder,
                longArrayOf(0, 120),
            ),
            Spec(
                "garage_general_v1",
                "Everything else",
                "Ratings, staff activity and other console alerts.",
                R.raw.alert_general,
                longArrayOf(0, 120),
            ),
        )

        for (s in specs) {
            val channel = NotificationChannel(
                s.id,
                s.title,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = s.blurb
                enableVibration(true)
                vibrationPattern = s.pattern
                setSound(
                    Uri.parse("android.resource://$packageName/${s.sound}"),
                    attrs,
                )
            }
            manager.createNotificationChannel(channel)
        }

        // `garage_alerts` was the single channel every alert used to land in,
        // and it exists on every handset that ran an earlier build. Its sound
        // cannot be changed now, and leaving it would show the workshop a
        // fifth switch in settings that no longer controls anything. Deleting
        // it is the only way to retire it; the four above replace it.
        manager.deleteNotificationChannel("garage_alerts")
    }

    /**
     * The chime for an alert the console shows while it is open.
     *
     * A pushed alert arrives with its channel's sound; an alert that lands
     * while the app is in the foreground does not, because Android does not
     * post a notification for it - the app is already showing. So the banner
     * was silent, and on a shop floor a silent banner is a banner nobody
     * sees. The counter is under a car with the phone on the bench.
     *
     * Deliberately the same four WAVs the channels use, by the same key, so
     * a booking sounds like a booking whether the console was open or not.
     * Nothing new is bundled and the two cannot drift apart.
     *
     * Played on the notification stream, so it follows the phone's ring
     * profile and goes quiet when the handset is silenced - a workshop that
     * has turned its phone down has said what it wants.
     */
    private var chime: MediaPlayer? = null

    private fun playAlertSound(kind: String?) {
        val res = when (kind) {
            "booking" -> R.raw.alert_booking
            "payment" -> R.raw.alert_payment
            "reminder" -> R.raw.alert_reminder
            else -> R.raw.alert_general
        }
        // One player at a time: two alerts landing together should chime
        // once, not overlap into noise.
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
                // A chime that will not play is never worth a crash on the
                // counter's phone. The banner still shows.
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
     * Whether Android already lets the console run in the background without
     * battery restrictions - what a pushed booking needs to arrive while the
     * app is shut on phones that stop idle apps hard (Xiaomi, Vivo, Oppo).
     */
    private fun runsUnrestricted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val power = getSystemService(PowerManager::class.java) ?: return true
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Android's own one-tap "let the app always run in the background?"
     * dialog, instead of a trip through Settings -> Apps -> Battery. Falls
     * back to the list screen on the odd phone that has no dialog.
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
