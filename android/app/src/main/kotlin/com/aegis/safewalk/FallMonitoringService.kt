package com.aegis.safewalk

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.*
import android.os.*
import android.location.*
import android.Manifest
import android.content.pm.PackageManager
import kotlin.math.sqrt
import kotlin.math.ceil

/** Native sensors and elapsed-time countdown remain independent of Flutter's UI. */
class FallMonitoringService : Service(), SensorEventListener, LocationListener {
    companion object {
        var current: FallMonitoringService? = null
            private set
        private const val STATUS_ID = 4101
        private const val ALERT_ID = 4102
        const val STATUS_CHANNEL = "fall_monitor_status"
        const val ALERT_CHANNEL = "fall_monitor_countdown"
        fun channels(context: android.content.Context) {
            if (Build.VERSION.SDK_INT >= 26) {
                val nm = context.getSystemService(NotificationManager::class.java)
                nm.createNotificationChannel(NotificationChannel(STATUS_CHANNEL, "Fall protection", NotificationManager.IMPORTANCE_LOW))
                nm.createNotificationChannel(NotificationChannel(ALERT_CHANNEL, "Possible fall", NotificationManager.IMPORTANCE_HIGH).apply {
                    enableVibration(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                })
            }
        }
    }
    private lateinit var sensors: SensorManager
    private val handler = Handler(Looper.getMainLooper())
    private var wakeLock: PowerManager.WakeLock? = null
    private var demo = false
    private var phase = "idle"
    private var deadline = 0L
    private var rotation = 0.0
    private var rotationAt = 0L
    private var impactAt = 0L
    private var stillSince = 0L
    private var lastTrigger = -20000L
    private var lastAccel = 0L
    private var lastGyro = 0L
    private var startedAt = 0L
    private var renewWakeAt = 0L
    private var failure: String? = null
    private var active = false
    private var eventId = ""
    private var latestLocation: Location? = null
    private var autoResult: Map<String, Any> = emptyMap()
    private var smsStartedAt = 0L
    private var eventOwner = ""
    private var eventLocation: Location? = null
    private var eventTime = 0L
    private var locationEnabled = false
    private var preparingLink = false
    private var liveUrl: String? = null
    private val locations by lazy { getSystemService(LOCATION_SERVICE) as LocationManager }
    private fun now() = SystemClock.elapsedRealtime()

    override fun onCreate() {
        super.onCreate()
        current = this
        channels(this)
        sensors = getSystemService(SENSOR_SERVICE) as SensorManager
    }
    override fun onBind(intent: Intent?) = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "stop" -> stopSelf()
            "cancel" -> cancelFall()
            "start" -> {
                demo = intent.getBooleanExtra("demo", false)
                val notification = statusNotification()
                locationEnabled = AutomaticSms.enabled && checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                if (Build.VERSION.SDK_INT >= 34) {
                    val types = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE or (if (locationEnabled) ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0)
                    startForeground(STATUS_ID, notification, types)
                } else if (Build.VERSION.SDK_INT >= 29 && locationEnabled) {
                    startForeground(STATUS_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
                } else startForeground(STATUS_ID, notification)
                if (locationEnabled) {
                    for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                        try { locations.requestLocationUpdates(provider, 15000L, 5f, this) } catch (_: Exception) {}
                    }
                }
                if (!active) {
                    val accel = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                    val gyro = sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
                    if (accel == null || gyro == null) {
                        fail("Required motion sensors are unavailable.")
                    } else {
                        val a = sensors.registerListener(this, accel, 50000)
                        val g = sensors.registerListener(this, gyro, 50000)
                        if (!a || !g) fail("Motion sensors could not start.") else {
                            active = true
                            startedAt = now()
                            wakeLock = (getSystemService(POWER_SERVICE) as PowerManager)
                                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "aegis:fall-monitor")
                                .apply { acquire(10 * 60 * 1000L) }
                            renewWakeAt = now() + 5 * 60 * 1000L
                            handler.post(tick)
                        }
                    }
                }
            }
        }
        // Never silently restart monitoring after a process kill or force-stop.
        return START_NOT_STICKY
    }

    private val tick = object : Runnable {
        override fun run() {
            if (!active) return
            if (now() >= renewWakeAt || wakeLock?.isHeld == false) {
                if (wakeLock?.isHeld == true) wakeLock?.release()
                wakeLock?.acquire(10 * 60 * 1000L)
                renewWakeAt = now() + 5 * 60 * 1000L
            }
            if ((phase == "idle" || phase == "countdown") && now() - startedAt > 10000 &&
                (now() - lastAccel > 10000 || now() - lastGyro > 10000)) {
                fail("Motion sensor updates stopped. Reopen Aegis and enable monitoring again.")
                return
            }
            if (phase == "countdown") {
                if (now() >= deadline) {
                    if (!demo && AutomaticSms.enabled) sendAutomaticFall()
                    else {
                        phase = "expired"
                        postAlert(if (demo) "Demo countdown finished. No alert sent."
                            else "Countdown ended. Open Aegis to prepare your alert. Nobody has been contacted.")
                    }
                } else postAlert("Possible fall. Are you OK? ${remaining()} seconds to cancel.")
            }
            if (phase == "sms_sending" && !preparingLink) {
                autoResult = AutomaticSms.status(this@FallMonitoringService, eventId)
                if (autoResult["state"] != "pending" || now() - smsStartedAt >= 20000) {
                    phase = "sms_complete"
                    postAlert(autoResult["message"].toString())
                    refreshStatus()
                }
            }
            handler.postDelayed(this, 1000)
        }
    }

    fun state(): Map<String, Any> = mapOf(
        "active" to active, "phase" to phase, "remaining" to remaining(),
        "demo" to demo, "eventId" to eventId, "error" to (failure ?: ""),
        "sms" to autoResult, "uid" to eventOwner, "time" to eventTime,
        "lat" to (eventLocation?.latitude ?: ""), "lng" to (eventLocation?.longitude ?: ""),
        "liveUrl" to (liveUrl ?: "")
    )
    private fun remaining() = ceil((deadline - now()).coerceAtLeast(0).toDouble() / 1000).toInt()
    fun claim(): Boolean {
        if (phase != "countdown" && phase != "expired") return false
        if (!demo && AutomaticSms.enabled) { sendAutomaticFall(); return false }
        phase = "dispatching"
        return true
    }
    private fun sendAutomaticFall() {
        if (phase != "countdown" && phase != "expired") return
        phase = "sms_sending"
        smsStartedAt = now()
        eventTime = System.currentTimeMillis()
        eventOwner = AutomaticSms.owner
        eventLocation = latestLocation?.takeIf {
            now() - it.elapsedRealtimeNanos / 1000000 in 0..120000 && it.hasAccuracy() && it.accuracy <= 100
        }
        val locationText = eventLocation?.let { "Location (recent GPS fix): https://maps.google.com/?q=${it.latitude},${it.longitude}" }
            ?: "Current location unavailable. Please call me immediately."
        val message = "SAFE WALK ALERT\nPossible fall detected; countdown was not cancelled.\nUser: ${AutomaticSms.name}\n$locationText"
        preparingLink = true
        postAlert("Preparing guardian SMS and location link.")
        SosLocationService.begin(this, eventId, eventLocation) { url ->
            if (current !== this || !active || phase != "sms_sending") return@begin
            preparingLink = false
            liveUrl = url
            smsStartedAt = now()
            val fullMessage = message + (url?.let { "\nLive location (private, up to 1 hour): $it\nDo not forward. Check the update time." } ?: "")
            try { autoResult = AutomaticSms.send(this, eventId, eventOwner, AutomaticSms.phones, fullMessage) }
            catch (_: Exception) { autoResult = mapOf("state" to "uncertain", "message" to "SMS result unknown. Check Messages and contact your guardian directly.", "count" to 0) }
            if (autoResult["state"] == "blocked" || autoResult["state"] == "uncertain") {
                phase = "sms_complete"
                postAlert(autoResult["message"].toString())
            } else postAlert("Sending guardian SMS. Delivery is not yet confirmed.")
        }
    }
    override fun onLocationChanged(location: Location) { latestLocation = location }
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
    @Deprecated("Deprecated in Android")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    fun setDemo(value: Boolean) { if (phase == "idle") { demo = value; reset(); refreshStatus() } }
    fun cancelFall() {
        if (phase != "countdown" && phase != "expired") return
        phase = "idle"
        reset()
        getSystemService(NotificationManager::class.java).cancel(ALERT_ID)
        refreshStatus()
    }
    private fun reset() { impactAt = 0; stillSince = 0; rotation = 0.0; rotationAt = 0 }
    private fun fail(message: String) {
        failure = message
        active = false
        phase = "error"
        sensors.unregisterListener(this)
        if (locationEnabled) { try { locations.removeUpdates(this) } catch (_: Exception) {} }
        if (wakeLock?.isHeld == true) wakeLock?.release()
        postAlert(message)
        refreshStatus()
    }
    override fun onSensorChanged(event: SensorEvent) {
        if (!active) return
        val t = now()
        val x = event.values[0].toDouble(); val y = event.values[1].toDouble(); val z = event.values[2].toDouble()
        val m = sqrt(x*x + y*y + z*z)
        if (!m.isFinite()) return
        if (event.sensor.type == Sensor.TYPE_GYROSCOPE) {
            rotation = m; rotationAt = t; lastGyro = t; return
        }
        lastAccel = t
        if (phase != "idle" || t - lastTrigger < 20000) return
        if (rotationAt == 0L || t - rotationAt > 500) { impactAt = 0; stillSince = 0; return }
        if (m >= (if (demo) 12.5 else 25.0) && rotation >= (if (demo) 0.6 else 2.5)) {
            if (demo) { trigger(t); return }
            impactAt = t; stillSince = 0
        }
        if (impactAt == 0L) return
        if (t - impactAt > 4000) { impactAt = 0; stillSince = 0; return }
        if (m in 7.5..12.5 && rotation < 0.7) {
            if (stillSince == 0L) stillSince = t
            if (t - stillSince >= 1000) trigger(t)
        } else stillSince = 0
    }
    private fun trigger(t: Long) {
        lastTrigger = t
        reset()
        phase = "countdown"
        eventId = java.util.UUID.randomUUID().toString()
        deadline = t + 15000
        refreshStatus()
        postAlert(if (demo) "Demo fall detected. 15 seconds to cancel." else "Possible fall. 15 seconds to cancel.")
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun openApp() = PendingIntent.getActivity(this, 0,
        Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun action(name: String) = PendingIntent.getService(this, if (name == "cancel") 1 else 2,
        Intent(this, FallMonitoringService::class.java).setAction(name),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun builder(channel: String): Notification.Builder =
        (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this))
            .setSmallIcon(R.mipmap.ic_launcher).setContentIntent(openApp())
            .setVisibility(Notification.VISIBILITY_PUBLIC)
    private fun statusNotification(): Notification = builder(STATUS_CHANNEL)
        .setContentTitle(if (failure != null) "Fall protection stopped" else if (phase != "idle") "Fall alert needs attention" else if (demo) "Demo fall monitoring active" else "Fall protection active")
        .setContentText(if (failure != null) "Open Aegis to restart." else if (phase != "idle") "Open Aegis to review the event. Further fall detection is paused." else "Monitoring movement, including when the screen is locked.")
        .setOngoing(true).addAction(Notification.Action.Builder(null, "Stop", action("stop")).build()).build()
    private fun refreshStatus() = getSystemService(NotificationManager::class.java).notify(STATUS_ID, statusNotification())
    private fun postAlert(text: String) {
        val notification = builder(ALERT_CHANNEL)
            .setContentTitle(if (demo) "Practice: possible fall" else "Fall protection")
            .setContentText(text).setStyle(Notification.BigTextStyle().bigText(text))
            .setCategory(Notification.CATEGORY_ALARM).setPriority(Notification.PRIORITY_HIGH)
            .setOnlyAlertOnce(true).setOngoing(true)
        if (phase == "countdown" || phase == "expired") {
            notification.addAction(Notification.Action.Builder(null, "I am OK — cancel", action("cancel")).build())
        }
        getSystemService(NotificationManager::class.java).notify(ALERT_ID, notification.build())
    }
    override fun onTaskRemoved(rootIntent: Intent?) { stopSelf(); super.onTaskRemoved(rootIntent) }
    override fun onDestroy() {
        active = false
        handler.removeCallbacksAndMessages(null)
        sensors.unregisterListener(this)
        if (locationEnabled) { try { locations.removeUpdates(this) } catch (_: Exception) {} }
        if (wakeLock?.isHeld == true) wakeLock?.release()
        getSystemService(NotificationManager::class.java).cancel(ALERT_ID)
        stopForeground(STOP_FOREGROUND_REMOVE)
        current = null
        super.onDestroy()
    }
}
