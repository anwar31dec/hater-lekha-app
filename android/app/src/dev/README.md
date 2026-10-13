# dev flavor overrides

Files in this folder are merged on top of `src/main` only for the `dev` flavor
(`flutter run --flavor dev`).

- `res/` — launcher icons with a red "DEV" band so testers can tell the two apps apart.

There is no flavor-specific `google-services.json` here: `android/app/google-services.json`
(Firebase project `hater-lekha-app`) contains clients for both `com.haterlekha.hater_lekha` and
`com.haterlekha.hater_lekha.dev`, and the Google Services Gradle plugin picks the one matching the
flavor's application id. The dev app id is `1:890856229289:android:d910622e843c4475fd5cb8`
(`FIREBASE_APP_ID_DEV` in `release_script.sh`).
