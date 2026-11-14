# Member 3 — Contacts & Safe Route

Branch: `feature/contacts-route-ui`

## What's in this module

| Feature | Screen | Service |
|---|---|---|
| Trusted contacts (add / edit / remove, primary guardian, call, swipe-to-delete + undo) | `screens/contacts/contacts_list_screen.dart`, `add_edit_contact_screen.dart` | `services/contacts_service.dart` |
| Medical info profile (blood type, allergies, conditions, emergency note) | `screens/contacts/medical_profile_screen.dart` | `ContactsService.saveMedicalProfile` |
| Hazard reporting (drop a pin with category + timestamp) | `screens/route/report_hazard_screen.dart` | `RouteSafetyService.reportHazard` |
| Nearby hazards map + "I saw it" confirmations | `screens/route/nearby_hazards_screen.dart` | `RouteSafetyService.streamNearbyHazards` |
| Route comparison (2 routes side by side, safety score + map preview) | `screens/route/route_comparison_screen.dart` | `RouteSafetyService.scoreRoutes`, `RoutePlannerService` |

Maps use **flutter_map + OpenStreetMap (CARTO dark tiles)** — no API key needed.

## Firestore data

* `users/{uid}/contacts/{contactId}` → `contactId, name, phone (+94…), relation, isPrimary, createdAt`
* `users/{uid}` → `bloodType, allergies, conditions, emergencyNote` (merged into the user doc)
* `hazard_reports/{reportId}` → `reportId, category, description, location{lat,lng}, geohash, reportedBy, reportedAt (Timestamp), confirmCount`
  * categories: `poor_lighting | unsafe_area | past_incident | no_sidewalk | other`
  * old docs with labels like "Broken Light" are still read correctly.

### Security rules needed (Member 4)

```
match /users/{uid}/contacts/{id} { allow read, write: if request.auth.uid == uid; }
match /hazard_reports/{id} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && request.resource.data.reportedBy == request.auth.uid;
  allow update: if request.auth != null
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['confirmCount', 'reportId']);
  allow delete: if request.auth.uid == resource.data.reportedBy;
}
```

## How the safety score works (explainable)

1. **Routes** – two walking routes from OSRM (FOSSGIS foot profile, falls back to
   the public OSRM server). If only one route exists, a detour via a side point is
   requested so there are always two options. Offline → "demo routes".
2. **Hazards (geoquery)** – reports are stored with a geohash. The area around both
   routes is covered with geohash prefixes (`GeoUtils.geohashPrefixesForRadius`),
   each prefix is a Firestore range query, results are filtered by real distance.
   A report counts if it is within **40 m** of the route line.
   * weight = category weight (past incident 2.0, unsafe area 1.5, poor lighting 1.0,
     no sidewalk 0.8, other 0.7) × confirmations boost (+25 % each, max ×2) × 0.5 if older than 30 days
   * hazard sub-score = 100 − 15 × total weight
3. **Lighting (Overpass API)** – streets within 25 m of the route; ratio of
   `lit=yes` vs `lit=no` OSM tags → lighting sub-score 0–100 (no data → neutral 50).
4. **Final score** = 60 % hazards + 40 % lighting. ≥ 75 Safe, ≥ 50 Moderate, else Risky.
   The "Why this score?" panel lists every factor.

Pure logic is unit-tested in `test/safe_route_test.dart` (`flutter test test/safe_route_test.dart`).

## Hooks for other members

* **SOS (Member 1 / 4):** `ContactsService().getEmergencyContacts(uid)` (primary first),
  `getMedicalProfile(uid)` and `MedicalProfile.toSosSummary()` for the SMS text.
  Drop-in UI: `EmergencyInfoPanel(uid: uid)` from `screens/contacts/widgets/medical_summary_card.dart`.
* **Trip (Member 2):** `RouteComparisonScreen(onRouteChosen: (route, score) { ... })`
  gives the chosen polyline (`route.points`) and destination (`route.points.last`).
* **Theme (all):** `AegisTheme.dark()` in `theme/aegis_theme.dart` + `AegisSpacing`,
  `AegisRadius`, `AegisColors.warning/danger/forScore()`.
