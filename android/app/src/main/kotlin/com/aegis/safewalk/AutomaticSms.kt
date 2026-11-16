package com.aegis.safewalk

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import org.json.JSONArray
import org.json.JSONObject

/** Explicit opt-in lasts for the signed-in session; never automatically retries SMS. */
object AutomaticSms {
    var owner = ""
    var phones = listOf<String>()
    var name = ""
    val enabled get() = owner.isNotEmpty() && phones.isNotEmpty()
    fun clear() { owner = ""; phones = emptyList(); name = "" }
    private fun prefs(c: Context) = c.getSharedPreferences("sms_results", Context.MODE_PRIVATE)
    fun configure(uid: String, numbers: List<String>, displayName: String) {
        require(uid.isNotBlank())
        require(numbers.isNotEmpty() && numbers.size <= 10)
        require(numbers.all { it.matches(Regex("^\\+[1-9][0-9]{6,14}$")) })
        owner = uid; phones = numbers.distinct(); name = displayName.take(80)
    }
    private fun problem(c: Context): String? {
        if (!enabled) return "Automatic SMS is off."
        return deviceProblem(c)
    }
    /** Permission / SIM checks shared by SOS SMS and trip SMS. */
    private fun deviceProblem(c: Context): String? {
        if (c.checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) return "SMS permission is missing."
        if (!c.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) return "This device cannot send SIM SMS."
        if (!SubscriptionManager.isValidSubscriptionId(SubscriptionManager.getDefaultSmsSubscriptionId())) return "Select a default SMS SIM in Android Settings and check that a SIM is installed."
        return null
    }
    fun readiness(c: Context) = problem(c)

    /**
     * Trip start/end messages: always sent automatically from the SIM when SMS
     * permission is granted. Independent of the SOS opt-in ([enabled]), so it
     * never changes SOS behaviour. Same duplicate protection as [send].
     */
    @Synchronized fun sendTrip(c: Context, id: String, numbers: List<String>, message: String): Map<String, Any> {
        if (prefs(c).contains(id)) return status(c, id)
        val reason = deviceProblem(c)
        if (reason != null || numbers.isEmpty() || numbers.size > 10 ||
            numbers.any { !it.matches(Regex("^\\+[1-9][0-9]{6,14}$")) } || message.length > 1600) {
            return mapOf("state" to "blocked", "message" to (reason ?: "Guardian numbers must be international, for example +94771234567."), "count" to 0)
        }
        return submit(c, id, numbers, message)
    }

    @Synchronized fun send(c: Context, id: String, uid: String, numbers: List<String>, message: String): Map<String, Any> {
        // The same incident ID is never submitted twice, even after process restart.
        if (prefs(c).contains(id)) return status(c, id)
        val reason = problem(c)
        if (uid != owner || reason != null || numbers.isEmpty() || numbers.size > 10 ||
            numbers.any { !it.matches(Regex("^\\+[1-9][0-9]{6,14}$")) } || message.length > 1600) {
            return mapOf("state" to "blocked", "message" to (reason ?: "SMS configuration changed; enable automatic SMS again."), "count" to 0)
        }
        return submit(c, id, numbers, message)
    }

    private fun submit(c: Context, id: String, numbers: List<String>, message: String): Map<String, Any> {
        val manager = SmsManager.getSmsManagerForSubscriptionId(SubscriptionManager.getDefaultSmsSubscriptionId())
        val parts = manager.divideMessage(message)
        val recipients = numbers.distinct()
        val states = JSONArray()
        repeat(recipients.size * parts.size) { states.put("pending") }
        val record = JSONObject().put("parts", states).put("count", recipients.size).put("time", System.currentTimeMillis())
        // Commit before invoking the modem: ambiguous failures must not cause duplicate sends.
        if (!prefs(c).edit().putString(id, record.toString()).commit()) {
            return mapOf("state" to "blocked", "message" to "Could not safely record this SMS attempt.", "count" to 0)
        }
        recipients.forEachIndexed { recipientIndex, phone ->
            val sent = ArrayList<PendingIntent>()
            parts.indices.forEach { partIndex ->
                val index = recipientIndex * parts.size + partIndex
                val intent = Intent(c, SmsStatusReceiver::class.java)
                    .setData(Uri.parse("aegis-sms://sent/$id/$index"))
                    .putExtra("id", id).putExtra("part", index)
                sent.add(PendingIntent.getBroadcast(c, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            try { manager.sendMultipartTextMessage(phone, null, parts, sent, null) }
            catch (_: Exception) {
                // It is not safe to assume an exception proves nothing was submitted.
                parts.indices.forEach { update(c, id, recipientIndex * parts.size + it, "unknown") }
            }
        }
        return status(c, id)
    }
    @Synchronized fun update(c: Context, id: String, part: Int, value: String) {
        val raw = prefs(c).getString(id, null) ?: return
        val json = JSONObject(raw)
        val parts = json.getJSONArray("parts")
        if (part !in 0 until parts.length()) return
        parts.put(part, value)
        prefs(c).edit().putString(id, json.toString()).commit()
    }
    @Synchronized fun status(c: Context, id: String): Map<String, Any> {
        val raw = prefs(c).getString(id, null) ?: return mapOf("state" to "missing", "message" to "No automatic SMS attempt.", "count" to 0)
        val json = JSONObject(raw)
        val parts = json.getJSONArray("parts")
        val values = (0 until parts.length()).map { parts.getString(it) }
        val state = when {
            values.all { it == "sent" } -> "sent"
            values.any { it == "failed" || it == "unknown" } -> "uncertain"
            else -> "pending"
        }
        val message = when (state) {
            "sent" -> "SMS sent to ${json.getInt("count")} guardian(s). Delivery is not confirmed."
            "uncertain" -> "Some SMS parts failed or have an unknown result. Contact your guardians directly; automatic retry is disabled to avoid duplicates."
            else -> "SMS submitted; sending is not yet confirmed. Check your Messages app. Do not assume delivery."
        }
        return mapOf("state" to state, "message" to message, "count" to json.getInt("count"))
    }
}

class SmsStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        AutomaticSms.update(context, id, intent.getIntExtra("part", -1), if (resultCode == Activity.RESULT_OK) "sent" else "failed")
    }
}
