# Member 1: SOS, fall countdown and demonstration mode

Branch: `feature/sos-fall-detection`.

## Integration and ownership

The SOS implementation is saved in commit 5dfe583. Latest main (687f351,
including Member 4 backend and Member 2 location/maps PR #16) is merged into
this branch. Team commit authorship is retained. No Firebase rules were deployed.
Temporary files and local configuration are excluded from the SOS commit.

Member 1 implementation:

- `services/safety/fall_detector.dart`: pure, testable motion heuristic.
- `motion_feed.dart`: accelerometer/gyroscope subscriptions at 50 ms intervals.
- `safety_controller.dart`: monitoring, countdown, cancellation, escalation,
  retry, duplicate suppression, resolution and lifecycle state.
- `sos_gateway.dart`: authenticated adapter to Member 4's alert service using a
  fresh GPS fix; optionally attaches the current active trip.
- `screens/safety/safety_shell.dart`: app-wide SOS control, full-screen event UI,
  monitoring controls and safe demonstration flow.

Backend integration corrections: missing profile service import, mismatched
contact decoder arguments, the old trip-mock test signature, and an unused
import. The obsolete dummy dashboard and message-only SOS/check-in actions were
replaced with actual safety controls. Route comparison, contacts, profile,
activity, compass and history remain reachable. The Safety dashboard now has a Start live trip button opening Member 2's
StartTripScreen and LiveMapScreen inside the safety navigator. Global SOS and
fall countdown overlays remain available over trip screens. No dummy live-sharing
claims remain on the Safety dashboard.

## Behavior

1. Sign in and complete the profile.
2. Monitoring is off by default. Enable **Fall monitoring** while the app stays
   in the foreground. Sensors stop on leaving the app, logout or disposal.
3. A suspected fall opens a 15-second **Are you OK?** countdown above any app page.
4. **I am OK - cancel** (or Back) stops it without writing an alert. **Escalate
   now** or expiration calls the same backend pipeline as manual SOS.
5. **Real SOS** bypasses the countdown. Repeated taps during the same event do not
   create additional requests. It remains real even when Demo mode is enabled.
6. The result shows whether the SMS composer or dialer opened, or whether no
   usable contacts were available. It never claims confirmed message delivery.
7. **I am safe - mark resolved** updates the record. It does not retract a sent
   message or send an all-clear to contacts.

When the app leaves the foreground, monitoring stops and a pending countdown is
cancelled. Resume does not silently re-enable it. This is an explicit foreground
MVP, not background/locked-screen protection. An already-started handoff can
finish while the SMS app is open. After an event, re-enable monitoring explicitly.

## Sensor algorithm and demo

Normal mode requires acceleration magnitude >=25 m/s^2 with rotation >=2.5 rad/s
from a gyro sample no older than 500 ms. The impact must be followed within four
seconds by at least one second of samples near gravity (7.5-12.5 m/s^2) and low
rotation (<0.7 rad/s). A trigger has a 20-second detector cooldown. These are
initial engineering thresholds, not measured sensitivity/specificity or a
validated medical detector. Phone placement and real motion require device QA.

Demo mode uses >=12.5 m/s^2 and >=0.6 rad/s, without the stillness stage. Enable
both switches and gently shake/rotate a securely held phone; never drop it.
**Practice countdown (no alerts)** provides a repeatable UI test without sensors.
Both automatic demo paths bypass GPS, Firestore, notification and external-app
dispatch. They end with **Demo completed**. Demo mode resets when backgrounded.

## Backend interface and honest delivery semantics

The adapter calls:

```dart
AlertService.instance.triggerAlert(
  userId: uid,
  type: AlertType.manualSos, // or AlertType.fallDetected
  lat: latitude,
  lng: longitude,
  tripId: optionalTripId,
  requestId: stableEventId,
);
```

`requestId` is an optional, backwards-compatible addition to Member 4's API.
Retries reuse the event document ID so a delayed write/retry cannot create two
different records. External composer delivery is not exactly-once; deliberately
retrying a failed handoff may open a composer again. A timeout can leave a saved
record even though the UI reports the operation could not complete.

No fallback Colombo coordinates are used. The current fix must be no older than
30 seconds, with reported accuracy <=100 m. GPS-off, permission denial or a
failed fix stops dispatch with an actionable error. A standalone SOS does not
require an active trip. Profile/contact read errors are surfaced, not treated as
an empty contact list. Local notification failure does not block the handoff.
Malformed phone numbers and `demo_` contacts from the seeder are excluded.

The SMS contains a static Google Maps location and the existing medical profile.
The unverified `safewalk.app` viewer link is removed. This pipeline opens the SMS
composer/dialer; it does not send unattended SMS or push to a guardian. Therefore
the original unresponsive-user automatic-delivery requirement still needs a real
backend transport from Member 4. Do not mark that requirement complete.

## Firestore rules: review/deploy separately

The local `firestore.rules` removes public trip/alert reads and the recursive
any-signed-in-user trip access. Trip/alert ownership cannot be changed on update.
Users can read/write their own profile and contacts. Guardian viewers are blocked
until Member 4 adds explicit authorized sharing. This is intentional; an ID alone
is not authorization.

No rules or indexes were deployed by this task. The previously published
profile-only rules are insufficient for real SOS: contacts and alerts also need
access. Member 4 must review, test in the Firebase emulator/Rules Playground, and
deploy the versioned rules/indexes before real-device integration testing. Verify
own reads/writes succeed, other-user and unauthenticated reads/writes fail, and
trip subcollections are not accessible through an overlapping wildcard. Rule
emulator tests have not been run here; no deployed security is certified.

## Validation and remaining device checks

38 automated tests passed in a single combined run: 19 new SOS tests plus the
existing 19 authentication/route/widget tests. Coverage includes detector
thresholds/stale gyro/cooldown, cancellation, single escalation, dry-run isolation,
sensor errors, lifecycle pause, retry IDs, explicit resolution, composer/dialer
semantics, rejected coordinates/users, and a countdown over a pushed app page.
All transport tests use fakes: no account, alert, SMS or call was created externally.

`flutter analyze --no-pub lib test` reports no issues, and
`flutter build bundle --debug --no-pub` completed successfully. The Android APK
attempt was stopped after its new D: Gradle cache made no progress downloading
the Gradle distribution; no APK/device-build success is claimed. Test temporary
files and the attempted Gradle cache were directed to D: rather than C:.

Member 6 should record build/commit, phone model and Android version for:

- Normal walking, stairs, sitting, phone handling and controlled motion; track
  false positives and misses before tuning thresholds.
- Gentle demo shake and practice countdown; verify no Firestore alert is created.
- Countdown cancel, manual escalation and timeout in real mode with consenting
  test contacts. Verify document ID, timestamp, coordinates and medical fields.
- Press Send in the composer and verify receipt on a second phone separately.
- GPS off/denied/inaccurate, denied notification permission, offline Firestore,
  missing contacts, malformed contacts and no SMS/dialer app.
- Background/lock during countdown, resume, logout and rapid repeated presses.
- Record resolution and confirm that previously sent SMS is not retracted.

Only use contacts who agreed to the test. Do not use the seed service's example
numbers for real dispatch. Background protection, unattended delivery, automatic
arrival detection and recipient acknowledgements remain future integration work.

## Latest-main integration phone check

On the Safety tab, use Start live trip to open the destination screen and then
start a trip. Confirm Real SOS remains visible over the live map. The trip module
still uses sample destination coordinates and foreground-only tracking; guardian
viewing requires a separate sharing/rules implementation. Maps needs the local
`android/secrets.properties` key documented in docs/maps-key-setup.md.

Post-merge validation: 44 tests passed across SOS, authentication, backend alerts, routes, widgets and location model integration. Flutter analysis reported no issues. Phone testing remains pending.
