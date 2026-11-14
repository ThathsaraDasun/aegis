# Member 1: authentication

## Flow

Firebase initialization -> splash -> auth-state gate -> sign in/create account
-> profile setup when needed -> existing main navigation.

- Email/password accounts are created using Firebase Authentication. Passwords
  are not stored in Firestore, logged, or trimmed.
- Registration has two steps: account creation, then full name and optional phone.
  If profile persistence fails, the account remains valid and the user can retry
  profile setup. Restarting or signing in again resumes setup instead of trying
  to create the same account twice.
- Accounts created in Firebase Console also complete profile setup on first login.
- Profile setup merges `userId`, `name`, and `phone` into `users/{uid}`. It does not
  replace medical information, notification tokens, contacts or other fields.
  Existing `UserModel` defaults handle absent optional medical fields.
- A nonblank stored name marks an existing profile as ready. The Profile screen
  now displays the signed-in user's Firestore data rather than the dummy profile.
- Firebase's native auth-state stream restores the Android session. No custom
  password/session storage is introduced.
- The authenticated area owns its own navigator. Sign-out disposes its pushed
  screens so Back cannot expose a previous user's pages.
- Failed login stays on the form. The old dashboard bypass/demo entry is removed.
- Firebase initialization failure displays a configuration error instead of
  opening screens that depend on an uninitialized Firebase instance.

## Backend prerequisites

Use the Android Firebase app matching `com.aegis.safewalk`; keep
`android/app/google-services.json` local and ignored. Enable Email/Password in
Firebase Authentication and provision Cloud Firestore.

Member 4 must ensure deployed rules allow authenticated users to read and
create/update their own `users/{uid}` profile while rejecting other users. This
change does not deploy rules or weaken existing rules. Profile permission errors
block entry and offer retry/sign-out. Confirm these permissions before device QA.

## Automated checks

Run `flutter pub get`, `flutter test`, and `flutter analyze --no-pub lib test`.
`test/auth_test.dart` tests input validation, failed login, password preservation,
registration confirmation, failed profile-save recovery, restored sessions,
sign-out clearing pushed routes, console-user setup and profile-read retry.
These use a fake service and do not prove deployed Firebase access works.

Validation on 13 November 2026: six authentication tests and eleven route tests
passed in the suite run; Windows locked compiler output before the last file, so
the two remaining widget/mock tests were run separately and passed. Analysis of
`lib` and `test` reports no issues. Two duplicate named arguments already present
in the merged compass screen were removed to unblock compilation.

The Android debug build was attempted but Gradle rejected the existing
`org.gradle.java.home=C:/Users/USER/.gradle/jdks/eclipse_adoptium-21-amd64-windows.2`
in `android/gradle.properties`. Configure a valid local JDK before device testing.
The first test attempt also exhausted C: temporary space; subsequent tests used
temporary storage on D:. No Firebase accounts or deployed configuration were
changed during automated tests.

The refreshed lockfile includes the map dependencies already added by the merged
Member 3 work; no new authentication dependency was introduced.

## Physical-device acceptance checklist (not yet executed)

Record commit/build, device/Android version, result and screenshots for each:

1. Start with no session: only sign-in/create-account is reachable.
2. Wrong password: show an error and remain signed out.
3. Register a new test email, confirm password, then save name/phone. Verify the
   account in Authentication and profile at `users/{uid}` in Firestore.
4. Register the same email again: show the existing-account error.
5. Sign in with the console-created test user: complete its missing profile.
6. Interrupt connectivity during profile saving: restore connectivity and finish;
   verify there is only one Auth account. Force-close/reopen during setup and
   verify setup resumes. A pending offline Firestore write may wait for reconnect.
7. Restart with a completed signed-in account: return to the dashboard.
8. Open a secondary screen, sign out, and press Back: no protected page remains.
9. Sign in as another user: Profile shows that user's data, not the previous user.
10. Deny profile access using a test environment/rules: show retry/sign-out, never
    enter the dashboard; restore access and retry.

Not included: password reset, email verification, account deletion, SOS, trip
integration or readiness checks. Those remain separate tasks.
