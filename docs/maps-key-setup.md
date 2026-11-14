# Google Maps key setup

The Android Gradle project is in `android/`. Copy `android/secrets.defaults.properties` to `android/secrets.properties`, then replace the placeholder locally. Do not put a real key into either tracked defaults file. The root-level default is not the Android build configuration.

The Secrets Gradle plugin reads `android/secrets.properties` and supplies `MAPS_API_KEY` to the application metadata in AndroidManifest.xml. Git ignores local.properties, secrets.properties and environment-specific secrets.*.properties files; defaults remain tracked placeholders.

Verify before committing:

```
git check-ignore android/secrets.properties
git ls-files -- android/secrets.properties secrets.properties local.properties android/local.properties
```

The first command should print the ignored path; the second should print nothing.

## Previously exposed key

Both PR #12 and #16 included the same commit history at comparison time (head 518690c). A real Google API key existed in local.properties in commit a1d9bec. A later teammate commit removed that file and introduced the secrets plugin. That removes the value from the current checkout, not from published Git history.

The key owner must replace/revoke the exposed key in Google Cloud and check its usage. Restrict the replacement to Maps SDK for Android and the app's package `com.aegis.safewalk` with the appropriate signing certificate SHA-1 fingerprints. Share the replacement privately and put it only in the ignored local file. Do not dismiss the GitGuardian finding solely because the file is now ignored.

No cloud key was rotated or revoked by this change. No repository history was rewritten.

Google guidance: https://developers.google.com/maps/api-security-best-practices
Android setup: https://developers.google.com/maps/documentation/android-sdk/config
