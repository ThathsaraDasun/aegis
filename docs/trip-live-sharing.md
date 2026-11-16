# Trip live-location sharing (Member 5)

Branch: `feature/trip-live-sharing`

When a user starts a trip, their guardians are alerted with a private live
link and can follow the walker in any browser until the trip ends.

## What it does

1. **Start Trip** creates `trip_shares/{token}` (random 64-hex token) and a link
   `https://aegis-45002.web.app/trip/#<token>`.
2. **Guardians are alerted**: "I started a Safe Walk. Follow my live location:
   <link>" goes to all saved guardians — automatically when *Automatic guardian
   SMS* is on, otherwise via **Notify by SMS / WhatsApp** on Live Tracking.
3. **During the trip** the position is uploaded about every 15 s, also with the
   screen locked (foreground notification "Sharing your Safe Walk").
4. **Trip end** ("I have arrived safely" or the 90-minute auto-end) revokes the
   link (`active: false`); the page then shows "The trip has ended". Links also
   expire after 4 h as a safety net. Sharing resumes after an app restart.
5. If the page is not deployed or the phone is offline, the trip still starts
   and the message falls back to a Maps link of the start point.
6. SOS sharing (`live_shares`, `/sos/`) is unchanged.

## Files

| File | Change |
|---|---|
| `firestore.rules` | New `trip_shares/{token}` block (same model as `live_shares`, max 12 h). Additions only. |
| `sos-viewer/trip/` | Guardian page (`index.html`, `trip.js`, `trip.css`, `ready.json`). Reuses `../sos/vendor/leaflet`. |
| `lib/services/trip_share_service.dart` | Start / upload / stop / resume. |
| `lib/screens/trip/start_trip_screen.dart` | Starts sharing and the guardian alert after the trip is created. |
| `lib/screens/trip/live_map_screen.dart` | Guardian card, Notify buttons, stops sharing at trip end. |
| `test/trip_share_service_test.dart` | 6 tests. |

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
