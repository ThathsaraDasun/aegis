# Member 4 Handoff Note & Integration Guide

**Role:** Member 4 — Backend & Alerts Engineer  
**Branch:** `feature/backend-alerts`

---

## 1. Team Integration Guide & Method Allocation

### Member 1 (Project Lead & SOS System)
- **Emergency SOS Dispatch:**
  Call `AlertService.instance.triggerAlert(userId: uid, type: AlertType.manualSos, lat: lat, lng: lng, tripId: tripId)` when Panic SOS is pressed.
- **Fall Detection Escalation:**
  Call `AlertService.instance.triggerAlert(userId: uid, type: AlertType.fallDetected, lat: lat, lng: lng, tripId: tripId)` when the "Are you OK?" countdown expires.
- **Alert Resolution:**
  Call `FirestoreService.instance.resolveAlert(alertId)` when user cancels or resolves an alert.

### Member 2 (Location & Maps Lead)
- **Start Trip:**
  Call `FirestoreService.instance.createTrip(tripModel)` when initiating a walk.
- **GPS Location Streaming:**
  Call `FirestoreService.instance.updateTripLocation(tripId, lat, lng)` on position updates.
- **End Trip:**
  Call `FirestoreService.instance.endTrip(tripId, status: TripStatus.completed)` upon arrival.
- **Stream Active Trip:**
  Call `FirestoreService.instance.streamActiveTrip(userId)` to monitor current trip state.

### Member 3 (Contacts & Safe Route Lead)
- **Contacts Management:**
  Use `FirestoreService.instance.streamContacts(userId)`, `addContact`, `updateContact`, `deleteContact`.
- **Hazard Reporting:**
  Use `FirestoreService.instance.addHazardReport(report)`, `confirmHazardReport(reportId)`, `getNearbyHazards(lat, lng, radiusMeters)`.
- **Medical Info:**
  Use `FirestoreService.instance.updateMedicalInfo(userId, bloodType: ..., allergies: ..., emergencyNote: ...)`.

### Member 5 (Compass & Secondary Views)
- **Trip History:**
  Use `FirestoreService.instance.streamTripHistory(userId)` for past trips list.
- **Alert Log Feed:**
  Use `FirestoreService.instance.streamAlerts(userId)` for emergency activity feed.

---

## 2. Manual Testing Checklist

1. **Seed Demo Data**: Run app, sign in, go to Profile screen (Debug mode), tap "Seed Demo Data", and confirm documents created in Firebase Console under `users`, `trips`, `alerts`, and `hazard_reports`.
2. **Security Rules Enforcement**: Verify in Firebase Rules Playground that unauthenticated writes are denied and users cannot modify another user's documents.
3. **Manual Panic SOS**: Tap "Panic SOS" button. Confirm alert document is created in Firestore `/alerts`, active trip status changes to `alerted`, local notification pops up, and SMS composer opens with pre-filled guardian numbers, Google Maps link, and medical info.
4. **Fall Detection Escalation**: Trigger Silent Check-in dialog, tap "Escalate SOS". Confirm alert doc created with type `fall_detected`, notification pops up, and SMS composer opens.
5. **No-Contacts Case**: Clear contacts for a test user and trigger SOS. Confirm app displays notification that no contacts are saved and creates alert doc without crashing.
6. **SMS Unavailable Fallback**: Test on a device/emulator without SMS capability. Confirm app falls back to opening phone dialer (`tel:`) for the primary contact.

---

## 3. Test Log Table (For Member 6 — QA & Defense Lead)

| Scenario | Expected Outcome | Actual Result (Member 6) | Pass/Fail |
|---|---|---|---|
| **1. Demo Data Seeding** | Batch creates 1 user profile, 2 contacts, 3 trips, 1 alert, 4 hazard reports in Firestore | | |
| **2. Security Rules Enforcement** | Unauthenticated or cross-user writes rejected by Firestore security rules | | |
| **3. Manual SOS Dispatch** | Creates alert doc, updates active trip to 'alerted', shows local notification, opens SMS composer with location & medical info | | |
| **4. Fall Detection Escalation** | Triggers alert doc with type 'fall_detected', sends SMS/notification, updates trip status | | |
| **5. SOS without Contacts** | Triggers local notification informing user no contacts exist; records alert doc without crashing | | |
| **6. SMS Unavailable Fallback** | Automatically opens tel: dialer for first primary contact when SMS app cannot launch | | |
