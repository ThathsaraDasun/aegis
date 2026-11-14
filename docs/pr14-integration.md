# PR 14 integration decisions

Merged current main into feature/compass-activity without rewriting teammate commits.

- Kept main's AuthGate, profile recovery, protected navigation and real SOS pipeline. Removed the old inline login/demo bypass. The current auth login/registration flow remains the app entry point; the separate redesigned RegisterScreen is retained but is not linked into that flow.
- Kept Member 5's compass, saved locations, profile editing, activity filters, trip details, recent activity preview and shared theme.
- Combined backend model fromMap/toMap APIs with activity parsing helpers, including GeoPoint support and legacy trip field compatibility.
- ActivityService uses the same user-owned Firestore collections and fields as FirestoreService. Client-side sorting and the combined activity stream remain intact.
- Unresolved alerts are labelled unresolved, not proof that contacts received a message. The backend opens an SMS composer/dialer and cannot confirm delivery.
- The GitGuardian finding in test/register_screen_test.dart is intentionally unchanged. The teammate must confirm whether the flagged test value has ever been used as a real credential and address the finding before merge.
