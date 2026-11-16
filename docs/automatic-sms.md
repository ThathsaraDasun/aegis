# Automatic guardian SMS (Android)

Automatic guardian SMS is off by default. While monitoring is off, enable it on Safety, accept the explanation, and grant SEND_SMS. Configure a default SMS SIM in Android Settings. A SIM, cellular coverage and SMS credit/bundle are required; multipart messages can cost multiple SMS. No cloud messaging provider/API key is used. WhatsApp remains manual.

The app loads up to ten real guardian numbers (excluding demo contacts), validates international format, and keeps a snapshot for the current session. Stop monitoring and re-enable Automatic guardian SMS after editing guardians. Signing out or starting a new Flutter engine clears the opt-in and native contact snapshot. Enabling requires a successful profile/contact read, so do this while online.

## Behaviour

- Real SOS keeps its existing fresh-GPS and Firestore prerequisites, then attempts SMS directly instead of opening a composer when opted in. If it cannot get GPS or save the alert, this foreground flow still fails before sending.
- An uncancelled real background countdown sends through the native service without opening Flutter or requiring Firestore connectivity. If available, a GPS fix no older than two minutes and with accuracy within 100m is included. Otherwise it explicitly says current location is unavailable and asks the guardian to call. Background messages include the profile name, not medical fields.
- The service starts location updates only when auto SMS is configured and fine-location permission is already granted. It declares the location foreground-service type and releases updates on stop. No GPS history is persisted by the service.
- Demo and practice countdowns never send. Manual Real SOS remains real even in demo mode.
- A sent callback for every SMS part is required before showing Sent. No delivery receipts are requested: sent is never described as delivered or received. Pending/unknown/failed parts produce an explicit uncertain status.
- Each incident ID is committed to a private SMS-attempt ledger before invoking SmsManager. Repeated calls for that ID return the existing result, never automatically resend. The ledger stores part status/count/time, not phone numbers or message text. An uncertain result requires checking Messages and contacting the guardian manually.
- Background results appear in a notification. On returning to Aegis the app attempts to save the event to Activity without sending again. If this save fails, the UI states it was not recorded. If the process/task is stopped before returning, the event is not automatically synced to Firestore; the SMS-attempt ledger still prevents resubmission of that incident ID.
- Further fall detection pauses while an event needs attention. Review it, dismiss the result and enable monitoring again.
- Normal SMS sending may appear in the default Messages app. Android/device/carrier restrictions can reject it. Play Store distribution needs a separate review of restricted SMS permission eligibility; this implementation is for the team's directly installed Android university build.

## Verification before demonstrating

Use only a consenting test guardian and check actual receipt on their phone. No live messages have been sent by the coding agent.

1. Automatic SMS off: Real SOS still uses manual composition.
2. Permission denied, no SIM, default SIM unset: configuration/sending fails visibly.
3. Automatic SMS on: Real SOS sends once with the correct location and recipients; verify recipient receipt separately.
4. Demo/practice, including while locked: zero SMS.
5. Real countdown cancellation, foreground and notification: zero SMS.
6. An agreed real background fall test: uncancelled countdown attempts SMS while locked. Verify content, recent location or explicit unavailable text, result notification and Activity on return. Do not drop a phone to test.
7. Airplane mode/no credit/multipart failures: never show Sent unless every part's sent callback succeeds; no duplicate automatic retry.
8. Logout, stop, task removal and app restart: no stale recipient sending; opt-in is off after a new engine starts.

Sources: https://developer.android.com/reference/android/telephony/SmsManager and https://developer.android.com/develop/background-work/services/fgs/service-types

The test suite and live SMS tests were not run at the user's request. Android compilation and Dart analysis are checked separately.
