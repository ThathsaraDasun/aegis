# Android background fall monitoring

Enable Fall monitoring while Aegis is open and allow notifications. Android now runs accelerometer/gyroscope detection and the 15-second countdown in a foreground service. A persistent notification has a Stop action. A possible fall posts an urgent notification with an I am OK — cancel action; tapping the notification opens Aegis. The service uses the existing impact/rotation/stillness thresholds, including the lower demo thresholds. It does not automatically enable protection at login.

## Important limits

- Switching apps or locking the screen does not intentionally stop protection. Removing the task from recent apps, signing out, stopping the service, force-stop, reboot, or process termination does. No silent restart after termination is implemented.
- Android/OEM battery controls and sensor availability can still interrupt service. A watchdog stops monitoring if sensor updates stop. This is not a validated medical detector.
- The service uses a partial wake lock while enabled to receive ordinary non-wakeup sensor events with the screen off. This consumes battery. All listeners, callbacks, notifications and the wake lock are released when stopped.
- Background countdown expiry leaves an action-required notification. It does NOT send SMS, open another app over the lock screen, or claim that a guardian was contacted. Open Aegis to run the existing GPS/database/message-preparation flow. Sending still requires user action. Demo expiry never dispatches a real alert.
- The in-app practice countdown is separate and stops monitoring before starting. Enable monitoring again afterwards.
- Notification permission and an enabled fall-alert channel are required. Android may silence or hide alerts through system settings; no full-screen-intent bypass is attempted.
- Trip GPS tracking is unchanged and remains foreground-only.
- `specialUse` foreground-service declaration describes phone motion fall detection; store distribution requires review of applicable Play foreground-service policies.

## Phone acceptance checks (not yet performed)

1. Rebuild the Android app (hot reload cannot install the service). Enable Demo mode, then Fall monitoring. Confirm the persistent notification appears.
2. Press Home, gently shake/rotate the phone, then place it still. Confirm the possible-fall notification and Cancel action. Never drop the phone.
3. Repeat with the screen locked, including several minutes of idle time. Confirm notification/vibration as permitted by system settings; cancel from the notification.
4. Let a demo countdown expire while locked. Open Aegis: demo finishes without any guardian dispatch.
5. Stop from the notification, then reopen Aegis. Confirm monitoring shows Off. Repeat sign-out and task removal; ensure no monitoring notification remains.
6. Deny notifications, disable the alert channel, and test battery saver. The UI must not claim active protection when startup fails.
7. Real-mode countdown and message receipt require an agreed test guardian. Automatic delivery is not implemented here.

Sources: https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview and https://developer.android.com/develop/background-work/services/fgs/service-types
