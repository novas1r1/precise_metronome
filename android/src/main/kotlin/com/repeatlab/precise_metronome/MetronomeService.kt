package com.repeatlab.precise_metronome

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.session.MediaButtonReceiver

/**
 * Foreground service that keeps the app process alive while the metronome
 * runs in the background, and shows a media-style notification for it.
 *
 * The audio engine itself lives in native code and continues producing
 * clicks regardless of this service, but without a foreground service
 * Android will kill the process shortly after backgrounding.
 *
 * The notification carries two lines of text, a play/pause toggle and a
 * stop button, and is backed by a [MediaSessionCompat] so it also shows up
 * on the lock screen and answers headset buttons. Whatever the user
 * presses is *reported* to Dart through [onAction] — the service never
 * touches the engine itself, so the app's state stays the single source of
 * truth. Dart then updates the notification with the state it settled on.
 *
 * Intents:
 *  - no action: show or update the notification from the extras;
 *  - [ACTION_PLAY], [ACTION_PAUSE], [ACTION_STOP]: a notification button;
 *  - [Intent.ACTION_MEDIA_BUTTON]: a headset or lock-screen button,
 *    forwarded by [MediaButtonReceiver].
 */
class MetronomeService : Service() {

    private var session: MediaSessionCompat? = null

    // What the notification shows. Kept so a button press can re-post it
    // unchanged; startForeground has to be called on every start anyway.
    private var title = "Metronome running"
    private var body: String? = null
    private var playing = true
    private var smallIcon = 0
    private var channelId = DEFAULT_CHANNEL_ID
    private var channelName = "Metronome"
    private var notificationId = DEFAULT_NOTIFICATION_ID

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        session = MediaSessionCompat(this, "precise_metronome").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = report(ACTION_PLAY)
                override fun onPause() = report(ACTION_PAUSE)
                override fun onStop() = report(ACTION_STOP)
                override fun onCustomAction(action: String?, extras: Bundle?) {
                    if (action == ACTION_STOP) report(ACTION_STOP)
                }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY, ACTION_PAUSE, ACTION_STOP -> report(intent.action!!)
            Intent.ACTION_MEDIA_BUTTON -> MediaButtonReceiver.handleIntent(session, intent)
            else -> readConfig(intent)
        }

        ensureChannel()
        publishState()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(notificationId, notification)
        }

        // If Android kills the process, a restarted service would only show
        // a stale notification with no engine behind it.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        session?.isActive = false
        session?.release()
        session = null
        super.onDestroy()
    }

    // ---------------------------------------------------------------- state

    private fun readConfig(intent: Intent?) {
        if (intent == null) return
        intent.getStringExtra(EXTRA_TITLE)?.let { title = it }
        if (intent.hasExtra(EXTRA_BODY)) body = intent.getStringExtra(EXTRA_BODY)
        if (intent.hasExtra(EXTRA_PLAYING)) playing = intent.getBooleanExtra(EXTRA_PLAYING, true)
        intent.getStringExtra(EXTRA_CHANNEL_ID)?.let { channelId = it }
        intent.getStringExtra(EXTRA_CHANNEL_NAME)?.let { channelName = it }
        if (intent.hasExtra(EXTRA_NOTIFICATION_ID)) {
            notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, DEFAULT_NOTIFICATION_ID)
        }
        if (intent.hasExtra(EXTRA_SMALL_ICON)) {
            smallIcon = resolveIcon(intent.getStringExtra(EXTRA_SMALL_ICON))
        }
    }

    /** An app drawable (or mipmap) by name, or 0 for the plugin's own icon. */
    private fun resolveIcon(name: String?): Int {
        if (name.isNullOrEmpty()) return 0
        val drawable = resources.getIdentifier(name, "drawable", packageName)
        if (drawable != 0) return drawable
        return resources.getIdentifier(name, "mipmap", packageName)
    }

    private fun report(action: String) {
        onAction?.invoke(action)
    }

    /**
     * Tells the session what is playing. The lock screen and the API 33+
     * system media controls build their text and buttons from this rather
     * than from the notification itself.
     */
    private fun publishState() {
        val session = session ?: return
        session.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, body ?: "")
                .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, body ?: "")
                .build()
        )
        val state = if (playing) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_STOP
                )
                .addCustomAction(
                    PlaybackStateCompat.CustomAction.Builder(
                        ACTION_STOP,
                        "Stop",
                        R.drawable.ic_precise_metronome_stop
                    ).build()
                )
                .setState(state, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1f)
                .build()
        )
    }

    // --------------------------------------------------------- notification

    private fun ensureChannel() {
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

    private fun buildNotification(): Notification {
        val toggle = if (playing) {
            NotificationCompat.Action(
                R.drawable.ic_precise_metronome_pause,
                "Pause",
                servicePendingIntent(ACTION_PAUSE)
            )
        } else {
            NotificationCompat.Action(
                R.drawable.ic_precise_metronome_play,
                "Play",
                servicePendingIntent(ACTION_PLAY)
            )
        }
        val stop = NotificationCompat.Action(
            R.drawable.ic_precise_metronome_stop,
            "Stop",
            servicePendingIntent(ACTION_STOP)
        )
        val builder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setSmallIcon(
                if (smallIcon != 0) smallIcon else R.drawable.ic_precise_metronome_notification
            )
            .setOngoing(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(toggle)
            .addAction(stop)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(session?.sessionToken)
                    .setShowActionsInCompactView(0, 1)
            )
            // Swiping the notification away (possible for a paused service
            // on API 34+) counts as stop.
            .setDeleteIntent(servicePendingIntent(ACTION_STOP))
        if (body != null) builder.setContentText(body)
        launchPendingIntent()?.let { builder.setContentIntent(it) }
        return builder.build()
    }

    private fun servicePendingIntent(action: String): PendingIntent {
        val intent = Intent(this, MetronomeService::class.java).setAction(action)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getForegroundService(this, action.hashCode(), intent, flags)
    }

    /** Brings the app's launcher activity to the front on tap. */
    private fun launchPendingIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_PLAYING = "playing"
        const val EXTRA_SMALL_ICON = "smallIcon"
        const val EXTRA_CHANNEL_ID = "channelId"
        const val EXTRA_CHANNEL_NAME = "channelName"
        const val EXTRA_NOTIFICATION_ID = "notificationId"
        const val DEFAULT_CHANNEL_ID = "precise_metronome"
        const val DEFAULT_NOTIFICATION_ID = 4201

        const val ACTION_PLAY = "com.repeatlab.precise_metronome.PLAY"
        const val ACTION_PAUSE = "com.repeatlab.precise_metronome.PAUSE"
        const val ACTION_STOP = "com.repeatlab.precise_metronome.STOP"

        /**
         * Where button presses go. The plugin sets this while it is attached
         * to a Flutter engine and forwards them to Dart. Same process, so a
         * plain callback does.
         */
        @Volatile
        var onAction: ((String) -> Unit)? = null
    }
}
