# OpenStreetMap trip maps

No Google Maps API key, billing account or secrets.properties is required for trip maps. Firebase configuration is still required for authentication and database access. Previously exposed keys must still be revoked by their owner.

## Phone test

1. Rebuild and install the app; hot reload cannot remove native plugins.
2. Sign in, open Safety > Start live trip, and allow location access.
3. Wait for GPS, then tap a destination on the map. Start trip stays disabled until a pin is selected.
4. Start trip, walk a short distance and check the position marker and blue travelled path. Verify destination and GPS updates in Firestore.
5. Verify Real SOS remains accessible. Use consenting contacts for real alerts.
6. Tap I have arrived safely and check that the trip ends. Also test denied permission, GPS off and network failures.

The viewer uses the same renderer but still obeys owner-only Firestore rules; this does not implement guardian authorization. Tracking is foreground-only. The blue trail is retained for this screen session, not saved route history. Destination search and map-tap selection are supported; turn-by-turn navigation is not included.

## Destination search

Tap Search for a shop, school or address, enter a name and town, and press Search. Choose a result and check its pin before starting. Only the destination coordinates are saved in the trip. Search does not calculate a walking route.

Search uses Nominatim without an API key. Explicit submissions only (no autocomplete), an identified User-Agent, an in-memory cache of up to 100 queries, and a minimum 1.1 seconds between requests on this app instance reduce load. This per-device throttle is not an aggregate multi-user limit: before wider distribution use a provider/proxy that enforces the provider's total usage limits. Public hosting is best-effort for light demonstration use. Search text is sent to the provider; GPS coordinates are not included in the search request. Results depend on OSM coverage.

The endpoint can be replaced at build time with `--dart-define=DESTINATION_SEARCH_URL=https://your-provider/search` (Nominatim-compatible JSON required). No search requests are sent while typing. Users can cancel, retry, or use map pins if search is unavailable.

Policy: https://operations.osmfoundation.org/policies/nominatim/

Destination-search changes have not been run through tests or a device build yet; test runs were skipped at the user's request.

## Tile service

Standard tiles: https://tile.openstreetmap.org/{z}/{x}/{y}.png
Visible linked attribution is outside map overlays. Requests identify com.aegis.safewalk. flutter_map 8.3.2 uses built-in HTTP-aware caching on Android. Viewport prefetch buffers are zero. No bulk/offline download feature is provided. Public OSM hosting is best-effort and subject to its usage policy, not unlimited production hosting.

https://operations.osmfoundation.org/policies/tiles/
https://docs.fleaflet.dev/layers/raster-tile-layer/caching

Safe-route screens retain their existing OSM/CARTO renderer. Google Maps dependencies and Gradle key injection were removed. Existing ignored secret files are untouched.

Validation: 47 combined automated tests passed, Flutter analysis reported no issues, and the debug Flutter bundle compiled. Android APK/device testing remains pending.
