# Guardian live sharing (Member 4)

Scope §3.3 / §9: "Contact receives an alert with a live-location link."

## How it works

1. **Trip start.** `FirestoreService.createTrip` gives every active trip a
   `shareToken` (32 bytes from `Random.secure`, 64 hex chars, see
   `lib/services/share_token.dart`). In one batch it writes `trips/{tripId}`
   (now with `shareToken`) and the public mirror `shared_trips/{shareToken}`.
2. **Mirror.** `shared_trips/{shareToken}` holds only
   `userId, currentLocation, destination, status, alerted, updatedAt`
   (`lib/models/shared_trip_model.dart`). No trip ID, name or medical data.
3. **Sync.** `updateTripLocation`, `endTrip` and `markTripAlerted` take an
   optional `shareToken`:
   - location updates → mirror `currentLocation`
   - SOS / fall → mirror `alerted: true`, status stays `active` so the
     guardian can keep following during the emergency
   - trip end ("Arrived safely" or 90-minute timeout) → mirror `status: ended`
   Mirror writes are best-effort; they never block the owner's trip write.
4. **SOS message.** `AlertService` adds
   `Live location (Aegis app): aegis://live/<shareToken>` when the SOS belongs
   to a running trip. The static `https://maps.google.com/?q=lat,lng` link is
   always kept as the fallback.
5. **Opening the link.** `AndroidManifest.xml` registers `aegis://live`.
   `main.dart` routes the link to `LiveLocationViewerScreen.shared(shareToken)`,
   which calls `FirestoreService.streamSharedTrip`. No sign-in is needed.

## Security rules

```
match /shared_trips/{shareToken} {
  allow get:    if resource.data.status == 'active';   // token holders only
  allow list:   if false;                              // no enumeration
  allow create: owner only, 64-hex doc ID, status 'active', fixed fields
  allow update: owner only, userId unchanged, status active|ended, fixed fields
  allow delete: owner only
}
```

All other rules are unchanged; `/trips` and `/alerts` stay owner-only.
The token is the only secret: anyone it is sent to can watch the trip until
it ends.

## Testing

- Dart: `flutter test` (token, link parsing, mirror model, SOS message, routes).
- Rules: from `rules-test/`, run `npm install` then `npm test` (needs Java and
  firebase-tools). 16 emulator tests cover token reads while active, no list,
  ended mirrors locked, owner-only writes, and `/trips` staying owner-only.

## Not done / to check

- Rules are **not deployed**. After review, deploy to `aegis-45002` with
  `firebase deploy --only firestore:rules`.
- `aegis://` links open only on phones with Aegis installed, and some SMS
  apps don't make custom schemes tappable. An https link would need a hosted
  page (for example Firebase Hosting with App Links).
- Device check (Samsung A05s, debug APK): `adb shell am start -a
  android.intent.action.VIEW -d aegis://live/<token>` opens the viewer on cold
  and warm start; back returns to the home screen on warm start, and malformed
  links show the "not valid" message. Viewing a real trip needs the rules
  deployed first.
