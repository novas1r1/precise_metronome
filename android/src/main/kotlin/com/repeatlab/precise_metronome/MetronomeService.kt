package com.repeatlab.precise_metronome

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the app process alive while the metronome
 * runs in the background. The audio engine itself lives in native code
 * and continues producing clicks regardless of this service, but without
 * a foreground service Android will kill the process shortly after
 * backgrounding.
 *
 * The service carries no state — starting it means "keep the process
 * alive for audio"; stopping it releases that guarantee.
 */
class MetronomeService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Metronome running"
        val body = intent?.getStringExtra(EXTRA_BODY)
        val channelId = intent?.getStringExtra(EXTRA_CHANNEL_ID) ?: DEFAULT_CHANNEL_ID
        val channelName = intent?.getStringExtra(EXTRA_CHANNEL_NAME) ?: "Metronome"
        val notificationId =
            intent?.getIntExtra(EXTRA_NOTIFICATION_ID, DEFAULT_NOTIFICATION_ID)
                ?: DEFAULT_NOTIFICATION_ID

        ensureChannel(channelId, channelName)
        val notification = buildNotification(channelId, title, body)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(notificationId, notification)
        }

        return START_STICKY
    }

    private fun ensureChannel(channelId: String, channelName: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(channelId) == null) {
                val channel = NotificationChannel(
                    channelId,
                    channelName,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    setShowBadge(false)
                    setSound(null, null)
                    enableVibration(false)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun buildNotification(
        channelId: String,
        title: String,
        body: String?
    ): Notification {
        val builder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
        if (body != null) builder.setContentText(body)
        return builder.build()
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_CHANNEL_ID = "channelId"
        const val EXTRA_CHANNEL_NAME = "channelName"
        const val EXTRA_NOTIFICATION_ID = "notificationId"
        const val DEFAULT_CHANNEL_ID = "precise_metronome"
        const val DEFAULT_NOTIFICATION_ID = 4201
    }
}
