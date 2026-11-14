# PR 16 integration

- Preserved main authentication, profile recovery, SOS and shared Firestore service.
- Adapted location screens to the shared map-based TripModel and backend method signatures; retained GeoPoint read compatibility.
- Kept Android permissions and SMS/dialer package queries; placed Maps API metadata under application, where the Maps SDK reads it.
- Removed the machine-specific Java path. Maps still requires each developer's local Android MAPS_API_KEY configuration.
- Preserved foreground trip/map screens. Trip streams can return null; the viewer now reports missing/inaccessible trips. Tracker subscriptions are disposed.
- Removed claims that storing a trip confirms guardian notification.

## Remaining teammate work

- Both PR #12 and #16 originally pointed to commit 518690c; this resolution is for #16 only.
- The exposed key was removed from the branch tip by the teammate, but remains in Git history. The key owner must rotate/revoke it and restrict the replacement. GitGuardian may continue flagging the historical commit.
- Destination selection still uses the branch's documented sample coordinates, not the entered destination name.
- Cross-account guardian viewing is not authorized by the current owner-only Firestore rules. Add an explicit guardian access design; do not open trips publicly.
- Tracking is foreground only, not a tested background service. Timeout handling does not dispatch an SOS.
- Validate maps, permissions, GPS updates and end-trip behavior on a configured Android device.
