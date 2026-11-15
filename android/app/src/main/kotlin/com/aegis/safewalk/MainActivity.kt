package com.aegis.safewalk

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.app.NotificationManager
import android.os.Build
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aegis/fall_monitor").setMethodCallHandler { call, result ->
            when (call.method) {
                "permission" -> {
                    FallMonitoringService.channels(this)
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionResult != null) result.success(false) else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4103)
                        }
                    } else result.success(notificationsEnabled())
                }
                "start" -> {
                    if (!notificationsEnabled()) { result.error("notifications", "Enable Aegis notifications in Android Settings first.", null) }
                    else try {
                        val intent = Intent(this, FallMonitoringService::class.java).setAction("start")
                            .putExtra("demo", call.argument<Boolean>("demo") ?: false)
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
                        Handler(Looper.getMainLooper()).postDelayed({ result.success(true) }, 250)
                    } catch (e: Exception) { result.error("start_failed", "Android could not start fall protection.", null) }
                }
                "state" -> result.success(FallMonitoringService.current?.state() ?: mapOf("active" to false, "phase" to "stopped"))
                "claim" -> result.success(FallMonitoringService.current?.claim() ?: false)
                "stop" -> { stopService(Intent(this, FallMonitoringService::class.java)); result.success(null) }
                "cancel" -> { FallMonitoringService.current?.cancelFall(); result.success(null) }
                "demo" -> { FallMonitoringService.current?.setDemo(call.argument<Boolean>("demo") ?: false); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private fun notificationsEnabled(): Boolean {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 24 && !nm.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(FallMonitoringService.ALERT_CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return false
        return true
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4103) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED && notificationsEnabled())
            permissionResult = null
        }
    }
}
