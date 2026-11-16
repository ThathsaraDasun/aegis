# Trip live-location sharing (Member 5)

Branch: `feature/trip-live-sharing`

When a user starts a trip, their guardians are alerted with a private live
link and can follow the walker in any browser until the trip ends.

## What it does

1. **Start Trip** creates `trip_shares/{token}` (random 64-hex token) and a link
   `https://aegis-45002.web.app/trip/#<token>`.
2. **Guardians are alerted automatically by SMS from the SIM**: "I started a
   Safe Walk. Follow my live location: <link>" goes to all saved (non-demo)
   guardians. Android asks for SMS permission once. If permission is denied
   or there is no SMS SIM, Live Tracking shows **Notify by SMS / WhatsApp**.
3. **During the trip** the position is uploaded about every 15 s, also with the
   screen locked (foreground notification "Sharing your Safe Walk").
4. **Trip end** ("I have arrived safely" or the 90-minute auto-end) revokes the
   link (`active: false`); the page then shows "The trip has ended". Links also
   expire after 4 h as a safety net. Sharing resumes after an app restart.
5. **Trip-end SMS, also automatic**: "I have arrived safely…" — or, after the
   90-minute auto-end without confirmation, "…Please check on me. Last known
   location: <maps link>". The trip summary shows the result (or the manual
   buttons as a fallback).
6. **Slow connection**: ending a trip no longer fails with a timeout; the end is
   saved on the phone and synced later ("Saved on this phone…").
7. If the page is not deployed or the phone is offline, the trip still starts
   and the start message falls back to a Maps link of the start point.
8. SOS is unchanged: SOS sharing (`live_shares`, `/sos/`) and the Safety page
   "Automatic guardian SMS" opt-in still apply only to SOS/fall alerts. Trip
   SMS uses a separate native path (`smsSendTrip` → `AutomaticSms.sendTrip`)
   with the same duplicate protection. Each trip sends 2 SMS per guardian.

## Files

| File | Change |
|---|---|
| `firestore.rules` | New `trip_shares/{token}` block (same model as `live_shares`, max 12 h). Additions only. |
| `sos-viewer/trip/` | Guardian page (`index.html`, `trip.js`, `trip.css`, `ready.json`). Reuses `../sos/vendor/leaflet`. |
| `lib/services/trip_share_service.dart` | Start / upload / stop / resume. |
| `lib/screens/trip/start_trip_screen.dart` | Starts sharing and the guardian alert after the trip is created. |
| `lib/screens/trip/live_map_screen.dart` | Guardian card, Notify buttons, stops sharing at trip end; trip end no longer times out on slow connections. |
| `lib/screens/trip/trip_summary_screen.dart` | "Tell your guardians" card with the automatic trip-end SMS result / fallback buttons. |
| `lib/services/alert_service.dart` | Shared trip start/end message helper, `buildTripEndMessage`, `prepareTripEndShare`, automatic trip SMS (`sendTripSms`). |
| `lib/services/automatic_sms_service.dart` | `sendTripMessage` (asks SMS permission, calls `smsSendTrip`). |
| `android/.../AutomaticSms.kt`, `MainActivity.kt` | Native `sendTrip` / `smsSendTrip`, independent of the SOS opt-in. |
| `test/trip_share_service_test.dart`, `test/trip_end_message_test.dart`, `test/alert_service_test.dart` | Sharing, trip-end message and automatic trip SMS tests. |

## Deployment (Member 1 — project owner)

The app only sends trip links once `/trip/ready.json` is online, so nothing
breaks before this step.

1. Check out the branch (or `main` after the PR is merged) and compare the
   published Firestore rules with `firestore.rules`. The CLI **replaces** the
   published rules, so keep any newer rules a teammate deployed.
2. Deploy:

   ```bash
   firebase deploy --project aegis-45002 --only "firestore:rules,hosting"
   ```

   Hosting republishes `sos-viewer/` (the existing `/sos/` page unchanged, plus
   the new `/trip/` page).
3. Verify: <https://aegis-45002.web.app/trip/ready.json> shows `{"version":1}`
   and <https://aegis-45002.web.app/sos/ready.json> still works.

## Phone acceptance check

1. Start a short trip with at least one guardian saved.
2. Send the alert (or confirm the automatic SMS arrived).
3. Open the link in a browser on another device: the map and destination show.
4. Lock the phone and walk ~100 m: the page updates within ~30 s.
5. Tap **I have arrived safely**: the page shows "The trip has ended".
