# SOS browser location sharing

Implemented on `feature/sos-live-sharing`. Deployed to `aegis-45002` on 16 November 2026 after confirming the published rules matched the branch baseline and Hosting had no existing release. Firebase compiled and released the new rules; the viewer and readiness endpoint both returned HTTP 200. Android ARM64 Kotlin compilation passed; Dart analysis reported only the pre-existing profile editor deprecation. No test suites, live SOS events or SMS sends were run. A rebuilt installation still needs the manual phone acceptance check below.

## What the user sees

- A real SOS attempts to start one live-location session. Manual SMS, automatic SIM SMS and per-guardian WhatsApp messages include the private link **only after** the viewer readiness check and database creation succeed.
- The guardian opens the link in a browser, without Aegis or a login. The map shows the latest position, its age and accuracy. It refreshes about every 15 seconds while visible.
- Sharing continues in an Android location foreground service after opening Messages, locking the screen or dismissing the SOS result. A persistent notification provides **Stop sharing**.
- **I am safe – stop sharing** revokes the link and resolves the alert. Signing out also revokes first. If revocation cannot be confirmed online, updates stop locally and the UI explains that the last position can remain accessible until expiry. Reconnect and retry; sign-out waits for this revocation.
- Each link expires server-side after at most one hour. Repeated SOS actions during that hour use the same session; resolving any of them ends that session. No automatic renewal.
- With automatic SMS and real fall monitoring enabled, the location service is prepared while the app is visible. It uploads nothing until a real SOS occurs. Demo fall events do not share location or send messages. Real SOS remains real in demo mode.
- GPS, internet, Android permissions and battery policies affect updates. Force-stop/process death can stop updates; the viewer labels old positions. A recorded alert, browser link, opened composer or submitted SMS is **not** proof that a guardian received it.

## Deployment (required before a link can be included)

The app deliberately falls back to a static SOS location until the viewer is deployed and the Firestore rules allow creating a session.

1. Authenticate the Firebase CLI using the Google account that manages `aegis-45002`.
2. Compare the current published Firestore rules with `firestore.rules` before deploying. CLI rule deployment replaces the published rules; preserve any newer team rules.
3. Deploy the rules and static viewer:

   ```powershell
   firebase deploy --project aegis-45002 --only firestore:rules,hosting
   ```

   If using the local CLI cache installed for this task:

   ```powershell
   npm.cmd exec --cache D:\aegis\.dart_tool\firebase-cli-cache --yes --package firebase-tools -- firebase login
   npm.cmd exec --cache D:\aegis\.dart_tool\firebase-cli-cache --yes --package firebase-tools -- firebase deploy --project aegis-45002 --only "firestore:rules,hosting"
   ```

4. Viewer readiness endpoint: `https://aegis-45002.web.app/sos/ready.json`. It returns `{"version":1}`. The full link has a random fragment after `/sos/#`; the base page alone cannot show a location.
5. Rebuild and install Android; hot reload cannot install the new native service.

The viewer uses the default Firebase Hosting site. Check for an existing site before deploying: deploying this hosting config replaces its currently deployed files. No paid SMS/web backend, Google Maps key, service-account key or Firebase web API key is added. Hosting/Firestore free quotas still apply (one visible viewer makes about four reads per minute).

## Security and data

The viewer bundles Leaflet 1.9.4 CSS, JavaScript, icons and its license under `sos-viewer/sos/vendor/leaflet`. The CSS/JS integrity values were calculated/checked against those downloaded files. This replaces the original external CSS link whose incorrect integrity value caused browsers to reject the stylesheet and display scattered tiles. Only map tiles are fetched externally at runtime.

- `/live_shares/{token}` uses a cryptographically random 256-bit token. This is a bearer link: anyone who gets it can read until stopped/expired. Never post a real link publicly.
- Public access is single-document `get` only, while active and before expiry. Listing is always denied. The signed-in owner alone can create/update/delete. Updates cannot extend expiry, change owner, reactivate sharing or add fields.
- Stores only owner UID, current coordinates/accuracy and timestamps; no route history, guardian numbers, name or medical information. Existing `/users`, `/alerts` and `/trips` permissions are unchanged.
- The viewer reads via Firestore REST under security rules. App Check enforcement, if enabled later, needs a compatible browser strategy; do not disable enforcement casually to make the viewer work.
- Expiry blocks reads; it does not automatically delete documents. Expired records can be deleted administratively. The client retains a pending revocation token privately until confirmed or expired; it is never logged or committed.
- The token stays in the URL fragment. Hosting does not receive it. Cross-origin map requests receive only the site origin. No analytics is included. OpenStreetMap attribution stays visible.
- Offline queued uploads are bounded to one outstanding write and are rejected after expiry/revocation. An offline stop cannot retract a position already seen or cached by a guardian.

## Phone acceptance checklist (manual; no SMS sent by development tools)

Use a guardian who expects a test. First turn automatic SMS off, trigger SOS, and inspect the composer/link without sending. Open the link yourself in a private browser window. Confirm updates after walking, lock-screen updates, stale-position messaging without internet, and that Stop sharing prevents further reads. Confirm the app can sign out and no longer uploads. If testing automatic SMS later, confirm SIM credit, permission and guardian consent first. Do not drop the phone to simulate a fall.

Reference: https://firebase.google.com/docs/firestore/use-rest-api and https://firebase.google.com/docs/hosting/quickstart
