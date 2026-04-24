package com.majurun.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * RunTrackingService — Android foreground service that keeps GPS tracking alive
 * when the screen is locked or the user switches apps.
 *
 * Declared in AndroidManifest.xml with:
 *   foregroundServiceType="location|health"
 *
 * Flutter's geolocator plugin handles the actual GPS reads; this service
 * simply holds a foreground notification so the OS does NOT kill the process
 * during long runs.
 *
 * Usage (from Dart via MethodChannel or platform_channel):
 *   startForegroundService(Intent(context, RunTrackingService::class.java))
 *   stopService(Intent(context, RunTrackingService::class.java))
 */
class RunTrackingService : Service() {

    companion object {
        const val CHANNEL_ID = "run_tracking_channel"
        const val NOTIFICATION_ID = 1001

        // Actions sent from Flutter via startService(intent.putExtra("action", ...))
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP  = "ACTION_STOP"
        const val ACTION_UPDATE_STATS = "ACTION_UPDATE_STATS"

        // Extras
        const val EXTRA_DISTANCE = "distance"
        const val EXTRA_DURATION = "duration"
        const val EXTRA_PACE     = "pace"
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_STATS -> {
                val distance = intent.getStringExtra(EXTRA_DISTANCE) ?: "0.00 km"
                val duration = intent.getStringExtra(EXTRA_DURATION) ?: "00:00"
                val pace     = intent.getStringExtra(EXTRA_PACE)     ?: "--:--"
                val notification = buildNotification(distance, duration, pace)
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, notification)
                return START_STICKY
            }
            else -> {
                // ACTION_START or first start
                val notification = buildNotification("0.00 km", "00:00", "--:--")
                startForeground(NOTIFICATION_ID, notification)
                return START_STICKY
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        // App was swiped away — keep the service alive so the run continues.
        // The service will stop normally when stopRun() is called from Dart.
        super.onTaskRemoved(rootIntent)
    }

    // ── Notification ──────────────────────────────────────────────────────────

    private fun buildNotification(distance: String, duration: String, pace: String): Notification {
        val openIntent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        else
            PendingIntent.FLAG_UPDATE_CURRENT
        val pendingIntent = PendingIntent.getActivity(this, 0, openIntent, pendingFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MajuRun — Active Run")
            .setContentText("$distance • $duration • $pace/km")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Run Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps your run active while the screen is off"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }
}
