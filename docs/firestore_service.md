# Firestore & Alert Service API Documentation

Member 4 — Backend & Alerts Engineer API Reference.

## FirestoreService Methods (`lib/services/firestore_service.dart`)

### Users Collection (`/users/{uid}`)
- **`saveUserProfile(user)`**: Saves or merges a user profile document at `users/{userId}`.
- **`getUserProfile(userId)`**: Fetches a single user profile document by user ID.
- **`streamUserProfile(userId)`**: Streams real-time updates of a user profile document.
- **`updateMedicalInfo(userId, {bloodType, allergies, emergencyNote})`**: Merges emergency medical info fields onto `users/{userId}`.

### Contacts Sub-collection (`/users/{uid}/contacts/{contactId}`)
- **`addContact(userId, contact)`**: Creates a new guardian contact document, sets `contactId`, and returns the generated document ID.
- **`updateContact(userId, contact)`**: Merges updates onto an existing contact document at `users/{userId}/contacts/{contact.id}`.
- **`deleteContact(userId, contactId)`**: Deletes a guardian contact document.
- **`streamContacts(userId)`**: Streams real-time list of trusted contacts, ordered with primary guardians first.
- **`getContacts(userId)`**: One-shot fetch of trusted contacts for a user, ordered with primary guardians first.

### Trips Collection (`/trips/{tripId}`)
- **`createTrip(trip)`**: Creates a new live trip document with status `active`, sets `tripId`, and returns the generated ID.
- **`getTrip(tripId)`**: Fetches a single trip document by trip ID.
- **`streamTrip(tripId)`**: Streams real-time updates for a single trip document.
- **`updateTripLocation(tripId, lat, lng)`**: Updates `currentLocation` coordinates (`{lat, lng}`) on an active trip.
- **`endTrip(tripId, {status})`**: Marks a trip as `completed` (or custom status) and sets `endedAt` to server timestamp.
- **`markTripAlerted(tripId)`**: Updates a trip's status to `alerted` during an emergency.
- **`streamActiveTrip(userId)`**: Streams the current active trip document for a user.
- **`streamTripHistory(userId)`**: Streams past trip history documents for a user, ordered newest first (`startedAt` DESC).

### Alerts Collection (`/alerts/{alertId}`)
- **`createAlert(alert)`**: Creates a new emergency alert document (`fall_detected` or `manual_sos`) and returns the generated ID.
- **`resolveAlert(alertId)`**: Updates `resolved: true` on an alert document.
- **`getAlert(alertId)`**: Fetches a single alert document by alert ID.
- **`streamAlerts(userId)`**: Streams all emergency alerts for a user, ordered newest first (`triggeredAt` DESC).

### Hazard Reports Collection (`/hazard_reports/{reportId}`)
- **`addHazardReport(report)`**: Adds a crowd-sourced hazard report document and returns the generated ID.
- **`confirmHazardReport(reportId)`**: Increments `confirmCount` on a hazard report document by 1.
- **`streamHazardReports()`**: Streams all hazard reports ordered newest first (`reportedAt` DESC).
- **`getNearbyHazards(lat, lng, radiusMeters)`**: Queries a latitude band and filters longitude & Haversine distance on client.

---

## AlertService Methods (`lib/services/alert_service.dart`)

- **`init()`**: Initializes local notification plugin and requests Android 13+ notification permissions.
- **`triggerAlert({userId, type, lat, lng, tripId, requestId})`**: Records an alert, optionally marks its trip alerted, opens an SMS composer or dialer, and shows a local notification. Optional `requestId` reuses a document ID on retry. Authentication must match `userId`.
- **`buildMessage({user, type, lat, lng, tripId})`**: Formats a static Google Maps location and medical details. The unverified live-viewer URL has been removed.

`smsOpened` and `dialerOpened` report opened apps, not message delivery or a
connected call. `contactCount` counts unique usable phone numbers; contacts with
`demo_` IDs are excluded. Profile/contact read failures are surfaced. Database
failure prevents launching an external app. A local-notification failure is
nonfatal. Automatic unattended delivery is not implemented.
