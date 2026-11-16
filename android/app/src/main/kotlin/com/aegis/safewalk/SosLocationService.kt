package com.aegis.safewalk

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.*
import android.os.*
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import java.net.HttpURLConnection
import java.net.URL
import java.security.SecureRandom
import java.util.Date
import java.util.concurrent.Executors

/** One explicit, expiring SOS sharing session. No location history or contact data. */
class SosLocationService : Service(), LocationListener {
    companion object {
        var current: SosLocationService? = null
            private set
        private const val CHANNEL = "sos_live_location"
        private const val NOTIFICATION = 4110
        private val main = Handler(Looper.getMainLooper())
        private fun prefs(c: Context) = c.getSharedPreferences("sos_live_share", Context.MODE_PRIVATE)

        fun arm(context: Context): Boolean {
            if (current != null) return true
            if (context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) return false
            return try {
                val intent = Intent(context, SosLocationService::class.java)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
                true
            } catch (_: Exception) { false }
        }

        fun disarm() { current?.let { if (it.token == null && !it.preparing) it.stopSelf() } }

        fun begin(context: Context, id: String, location: Location?, callback: (String?) -> Unit) {
            if (!arm(context)) { callback(null); return }
            // Foreground service creation is delivered on the main looper.
            main.postDelayed({ current?.begin(id, location, callback) ?: callback(null) }, 200)
        }

        /** Also handles a previous process's session. Keep the token until the revoke is acknowledged. */
        fun stopSharing(context: Context, callback: (Boolean) -> Unit = {}) {
            current?.apply {
                token = null; preparing = false; generation++
                if (wakeLock?.isHeld == true) wakeLock?.release()
                if (AutomaticSms.enabled && FallMonitoringService.current != null && auth.currentUser?.uid == owner) refresh()
                else stopSelf()
            }
            val p = prefs(context)
            val oldToken = p.getString("token", null)
            val expires = p.getLong("expires", 0)
            if (oldToken == null || expires <= System.currentTimeMillis()) {
                p.edit().clear().apply(); callback(true); return
            }
            if (FirebaseAuth.getInstance().currentUser?.uid != p.getString("owner", "")) {
                callback(false); return
            }
            var returned = false
            val timeout = Runnable { if (!returned) { returned = true; warnPending(context); callback(false) } }
            main.postDelayed(timeout, 8000)
            FirebaseFirestore.getInstance().collection("live_shares").document(oldToken)
                .update("active", false).addOnCompleteListener { task ->
                    val revoked = task.isSuccessful || (task.exception as? FirebaseFirestoreException)?.code == FirebaseFirestoreException.Code.NOT_FOUND
                    if (revoked && p.getString("token", null) == oldToken) p.edit().clear().apply()
                    if (revoked) context.getSystemService(NotificationManager::class.java).cancel(4112)
                    if (!returned) { returned = true; main.removeCallbacks(timeout); if (!revoked) warnPending(context); callback(revoked) }
                }
        }
        private fun warnPending(context: Context) {
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
            val text = "Updates stopped. The link may still show your last position until its one-hour expiry. Reconnect and mark safe in Aegis."
            try { context.getSystemService(NotificationManager::class.java).notify(4112,
                builder.setSmallIcon(R.mipmap.ic_launcher).setContentTitle("Location link stop pending")
                    .setContentText(text).setStyle(Notification.BigTextStyle().bigText(text)).setVisibility(Notification.VISIBILITY_PRIVATE).build())
            } catch (_: Exception) {}
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val db by lazy { FirebaseFirestore.getInstance() }
    private val auth by lazy { FirebaseAuth.getInstance() }
    private val locations by lazy { getSystemService(LocationManager::class.java) }
    private var token: String? = null
    private var owner = ""
    private var alertId = ""
    private var expires = 0L
    private var preparing = false
    private var generation = 0
    private var latest: Location? = null
    private var lastUpload = 0L
    private var inFlight = false
    private var lastSuccess = 0L
    private var wakeLock: PowerManager.WakeLock? = null
    private val authListener = FirebaseAuth.AuthStateListener {
        if (owner.isNotEmpty() && it.currentUser?.uid != owner) stopSharing(this)
    }

    override fun onCreate() {
        super.onCreate()
        current = this
        if (Build.VERSION.SDK_INT >= 26) getSystemService(NotificationManager::class.java)
            .createNotificationChannel(NotificationChannel(CHANNEL, "SOS location sharing", NotificationManager.IMPORTANCE_LOW))
        owner = auth.currentUser?.uid ?: ""
        auth.addAuthStateListener(authListener)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") { stopSharing(this); return START_NOT_STICKY }
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(NOTIFICATION, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            else startForeground(NOTIFICATION, notification())
            for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                try { locations.requestLocationUpdates(provider, 15000L, 0f, this) } catch (_: Exception) {}
            }
            handler.removeCallbacks(tick)
            handler.postDelayed(tick, 15000)
        } catch (_: Exception) { stopSelf() }
        // A force-stop or process death must not silently restart sharing.
        return START_NOT_STICKY
    }

    private fun baseUrl() = "https://${FirebaseApp.getInstance().options.projectId}.web.app/sos/"
    private fun link(value: String) = "${baseUrl()}#$value"
    private fun fresh(l: Location) = l.latitude.isFinite() && l.longitude.isFinite() &&
        l.latitude in -90.0..90.0 && l.longitude in -180.0..180.0 && l.hasAccuracy() &&
        l.accuracy in 0f..100f && SystemClock.elapsedRealtime() - l.elapsedRealtimeNanos / 1000000 in 0..120000

    private fun begin(id: String, initial: Location?, callback: (String?) -> Unit) {
        if (token != null && expires > System.currentTimeMillis()) {
            // All SOS actions in the same hour share one session; resolving any ends it.
            callback(link(token!!)); return
        }
        if (preparing || auth.currentUser == null || !id.matches(Regex("^[a-zA-Z0-9_-]{1,100}$"))) { callback(null); return }
        // Do not overwrite a pending revoke left by a previous process.
        if (prefs(this).contains("token")) {
            stopSharing(this) { callback(null) }; return
        }
        preparing = true
        val attempt = ++generation
        owner = auth.currentUser!!.uid
        alertId = id
        if (initial != null && fresh(initial)) latest = initial
        var finished = false
        fun finish(url: String?) { if (!finished) { finished = true; callback(url) } }
        main.postDelayed({
            if (!finished) {
                if (attempt == generation && current === this) stopSharing(this)
                finish(null)
            }
        }, 9000)
        // Never distribute a link before the viewer is actually deployed.
        worker.execute {
            val ready = try {
                val connection = URL("${baseUrl()}ready.json").openConnection() as HttpURLConnection
                try {
                    connection.connectTimeout = 2500; connection.readTimeout = 2500
                    connection.instanceFollowRedirects = false
                    connection.responseCode == 200 && connection.inputStream.bufferedReader().use { it.readText().trim() } == "{\"version\":1}"
                } finally { connection.disconnect() }
            } catch (_: Exception) { false }
            handler.post {
                if (attempt != generation || finished) return@post
                if (!ready || auth.currentUser?.uid != owner) { preparing = false; finish(null); disarm(); return@post }
                val bytes = ByteArray(32); SecureRandom().nextBytes(bytes)
                val candidate = bytes.joinToString("") { "%02x".format(it.toInt() and 255) }
                expires = System.currentTimeMillis() + 60 * 60 * 1000
                prefs(this).edit().putString("token", candidate).putString("owner", owner).putLong("expires", expires).apply()
                val fix = latest?.takeIf(::fresh)
                val data = mutableMapOf<String, Any?>(
                    "ownerUid" to owner, "active" to true,
                    "createdAt" to FieldValue.serverTimestamp(), "expiresAt" to Timestamp(Date(expires)),
                    "updatedAt" to FieldValue.serverTimestamp(),
                    "lat" to fix?.latitude, "lng" to fix?.longitude,
                    "accuracy" to fix?.accuracy?.toDouble(), "fixAt" to fix?.let { Timestamp(Date(it.time)) }
                )
                db.collection("live_shares").document(candidate).set(data).addOnCompleteListener { task ->
                    if (attempt != generation || finished) return@addOnCompleteListener
                    preparing = false
                    if (task.isSuccessful && auth.currentUser?.uid == owner) {
                        token = candidate; lastSuccess = SystemClock.elapsedRealtime()
                        wakeLock = getSystemService(PowerManager::class.java)
                            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "aegis:sos-location")
                            .apply { acquire((expires - System.currentTimeMillis()).coerceIn(1L, 3600000L)) }
                        refresh(); finish(link(candidate))
                    } else {
                        // A rejected create did not publish a document; queued/offline creates time out above.
                        prefs(this).edit().clear().apply(); finish(null); disarm()
                    }
                }
            }
        }
    }

    private val tick = object : Runnable {
        override fun run() {
            if (token != null) {
                if (System.currentTimeMillis() >= expires) { stopSharing(this@SosLocationService); return }
                upload(); refresh()
            } else if (!preparing && FallMonitoringService.current == null) { stopSelf(); return }
            handler.postDelayed(this, 15000)
        }
    }

    override fun onLocationChanged(location: Location) { if (fresh(location)) { latest = location; upload() } }
    private fun upload() {
        val value = token ?: return
        val fix = latest?.takeIf(::fresh) ?: return
        if (inFlight || SystemClock.elapsedRealtime() - lastUpload < 15000 || auth.currentUser?.uid != owner) return
        lastUpload = SystemClock.elapsedRealtime(); inFlight = true
        db.collection("live_shares").document(value).update(mapOf(
            "lat" to fix.latitude, "lng" to fix.longitude, "accuracy" to fix.accuracy.toDouble(),
            "fixAt" to Timestamp(Date(fix.time)), "updatedAt" to FieldValue.serverTimestamp()
        )).addOnCompleteListener { task ->
            inFlight = false
            if (task.isSuccessful) lastSuccess = SystemClock.elapsedRealtime()
        }
    }

    private fun notification(): Notification {
        val open = PendingIntent.getActivity(this, 4110, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val stop = PendingIntent.getService(this, 4111, Intent(this, SosLocationService::class.java).setAction("stop"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        val text = if (token == null) "Ready for SOS. Your location is not being shared."
            else if (SystemClock.elapsedRealtime() - lastSuccess > 45000 || latest?.let(::fresh) != true) "Waiting for GPS or internet. Guardian may see an older location."
            else "Anyone with your SOS link can view. Stops after one hour."
        return builder.setSmallIcon(R.mipmap.ic_launcher).setContentTitle(if (token == null) "SOS location ready" else "SOS location sharing")
            .setContentText(text).setStyle(Notification.BigTextStyle().bigText(text)).setContentIntent(open)
            .setOngoing(true).setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(Notification.Action.Builder(null, "Stop sharing", stop).build()).build()
    }
    private fun refresh() = getSystemService(NotificationManager::class.java).notify(NOTIFICATION, notification())
    override fun onProviderEnabled(provider: String) {}
    override fun onProviderDisabled(provider: String) {}
    override fun onBind(intent: Intent?) = null
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        try { locations.removeUpdates(this) } catch (_: Exception) {}
        auth.removeAuthStateListener(authListener)
        worker.shutdownNow()
        if (wakeLock?.isHeld == true) wakeLock?.release()
        current = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
