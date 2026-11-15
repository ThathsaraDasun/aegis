# OpenStreetMap trip maps

No Google Maps API key, billing account or secrets.properties is required for trip maps. Firebase configuration is still required for authentication and database access. Previously exposed keys must still be revoked by their owner.

## Phone test

1. Rebuild and install the app; hot reload cannot remove native plugins.
2. Sign in, open Safety > Start live trip, and allow location access.
3. Wait for GPS, then tap a destination on the map. Start trip stays disabled until a pin is selected.
4. Start trip, walk a short distance and check the position marker and blue travelled path. Verify destination and GPS updates in Firestore.
5. Verify Real SOS remains accessible. Use consenting contacts for real alerts.
6. Tap I have arrived safely and check that the trip ends. Also test denied permission, GPS off and network failures.

The viewer uses the same renderer but still obeys owner-only Firestore rules; this does not implement guardian authorization. Tracking is foreground-only. The blue trail is retained for this screen session, not saved route history. Map-tap selection is supported; address search and turn-by-turn navigation are not included.

## Tile service

Standard tiles: https://tile.openstreetmap.org/{z}/{x}/{y}.png
Visible linked attribution is outside map overlays. Requests identify com.aegis.safewalk. flutter_map 8.3.2 uses built-in HTTP-aware caching on Android. Viewport prefetch buffers are zero. No bulk/offline download feature is provided. Public OSM hosting is best-effort and subject to its usage policy, not unlimited production hosting.

https://operations.osmfoundation.org/policies/tiles/
https://docs.fleaflet.dev/layers/raster-tile-layer/caching

Safe-route screens retain their existing OSM/CARTO renderer. Google Maps dependencies and Gradle key injection were removed. Existing ignored secret files are untouched.

Validation: 47 combined automated tests passed, Flutter analysis reported no issues, and the debug Flutter bundle compiled. Android APK/device testing remains pending.
