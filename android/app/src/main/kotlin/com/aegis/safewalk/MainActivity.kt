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
    private var smsPermissionResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // A new Flutter engine starts with opt-in off; do not retain old native recipients.
        stopService(Intent(this, FallMonitoringService::class.java))
        AutomaticSms.clear()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aegis/fall_monitor").setMethodCallHandler { call, result ->
            when (call.method) {
                "smsPermission" -> {
                    if (checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) result.success(true)
                    else if (smsPermissionResult != null) result.success(false)
                    else { smsPermissionResult = result; requestPermissions(arrayOf(Manifest.permission.SEND_SMS), 4104) }
                }
                "smsConfigure" -> {
                    try {
                        AutomaticSms.configure(call.argument<String>("uid") ?: "", call.argument<List<String>>("phones") ?: emptyList(), call.argument<String>("name") ?: "Aegis user")
                        val problem = AutomaticSms.readiness(this)
                        if (problem != null) { AutomaticSms.clear(); result.error("sms_unavailable", problem, null) }
                        else result.success(true)
                    } catch (_: Exception) { AutomaticSms.clear(); result.error("sms_configuration", "Use international guardian numbers, including the country code.", null) }
                }
                "smsDisable" -> { AutomaticSms.clear(); result.success(null) }
                "smsSend" -> {
                    val id = call.argument<String>("id") ?: ""
                    if (!id.matches(Regex("^[a-zA-Z0-9_-]{1,100}$"))) result.error("id", "Invalid alert ID", null)
                    else {
                        try {
                            val initial = AutomaticSms.send(this, id, call.argument<String>("uid") ?: "", call.argument<List<String>>("phones") ?: emptyList(), call.argument<String>("message") ?: "")
                            if (initial["state"] == "blocked") result.success(initial)
                            else {
                                val handler = Handler(Looper.getMainLooper())
                                var tries = 0
                                val check = object : Runnable {
                                    override fun run() {
                                        val state = AutomaticSms.status(this@MainActivity, id)
                                        if (state["state"] != "pending" || tries++ >= 20) result.success(state)
                                        else handler.postDelayed(this, 1000)
                                    }
                                }
                                handler.post(check)
                            }
                        } catch (_: Exception) { result.error("sms_failed", "Could not check SMS sending. Check Messages before retrying.", null) }
                    }
                }
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
        if (requestCode == 4104) {
            smsPermissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            smsPermissionResult = null
        }
    }
}
