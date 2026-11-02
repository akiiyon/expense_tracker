# Store readiness

What still stands between this code and the Play Store / App Store, most serious first.

## Blockers

### 1. The name "Expensify" is taken
Expensify, Inc. owns the trademark and has an expense app in both stores. Publishing under that name will get the listing rejected or taken down. Pick a new name, then change it in:

- `lib/core/config.dart` (`AppConfig.appName`, used in the app and on the splash)
- `android/app/src/main/AndroidManifest.xml` (`android:label`)
- `ios/Runner/Info.plist` (`CFBundleDisplayName`)

### 2. SMS permissions on Google Play
`READ_SMS` / `RECEIVE_SMS` are restricted by Google Play's *SMS and Call Log permissions* policy. Apps that aren't the default SMS app can only use them under an approved exception. As of writing, the policy lists SMS-based money management among the allowed exceptions, but check the current policy page before you submit. You need to:

1. Fill in the **Permissions Declaration Form** in Play Console, explaining that reading transaction SMS is core functionality.
2. Upload a short demo video showing the in-app disclosure (Profile → *Detect payments from SMS* shows it before asking for permission) and the feature working.
3. Make sure the privacy policy explains what is read and what is stored (amount, merchant, date; OTPs and personal messages are ignored and never leave the phone).

Approval isn't guaranteed and review takes longer. If it's refused, you have two options:

- **Ship without it.** Remove the two SMS permissions and the `<receiver>` from `AndroidManifest.xml`. The setting already hides itself when the feature isn't supported, so the rest of the app keeps working.
- **Use India's Account Aggregator framework** (e.g. via Setu or Finvu). It's the policy-safe way to read bank transactions, but it needs a business agreement.

**iOS:** Apple doesn't let any app read SMS. The feature is Android-only and hidden on iPhone.

### 3. The backend must be hosted on HTTPS
The app talks to the Node backend. Release builds only allow HTTPS (`android/app/src/main/res/xml/network_security_config.xml` allows plain HTTP only for `10.0.2.2` and `localhost`).

1. Host `backend/` (Render, Railway, Fly.io, etc.) together with a managed Postgres.
2. Set the env vars from `backend/.env.example`. `JWT_SECRET` must be a long random string.
3. Build the app pointing at it:
   ```
   flutter build appbundle --dart-define=API_URL=https://your-api.example.com --dart-define=PRIVACY_URL=https://your-site/privacy
   ```

### 4. Release signing
Create an upload key once and keep it safe. If you lose it, you can't update the app.
```
keytool -genkey -v -keystore %USERPROFILE%\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Then create `android/key.properties` (it's in .gitignore):
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:\\Users\\you\\upload-keystore.jks
```
Without this file, release builds are signed with the debug key, which Play rejects.

### 5. App ID
The ID is now `com.akshay.expensetracker` (`com.example.*` is rejected by Play). It can never change after the first upload, so pick the final one now: `applicationId` in `android/app/build.gradle.kts`, and the Bundle ID in Xcode.

## Required store paperwork
- **Privacy policy URL.** Needed because of financial data, SMS and microphone use. Pass it with `--dart-define=PRIVACY_URL=...`; Profile shows it.
- **Play Data safety form.** Declare: email and name (account), financial info (transactions), SMS (processed on device, only parsed fields uploaded), audio (speech recognition by the OS, not stored).
- **Account deletion.** In-app deletion is done (Profile → Delete account; `DELETE /auth/me` removes everything). Play also wants a web URL where users can request deletion.
- **Financial features declaration** (Play Console → App content). Choose "personal finance / budgeting". xp gives budgeting tips only and says it isn't a licensed advisor.
- **Screenshots and feature graphic.** Icons are in `store_assets/` (`play_store_icon_512.png`). Regenerate them with `flutter test tool/render_icons_test.dart` if the logo changes.

## iOS-specific
- Build on a Mac. After the first `pod install`, add the permission_handler flags to `ios/Podfile` or the mic permission prompt never appears:
  ```ruby
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_MICROPHONE=1', 'PERMISSION_SPEECH_RECOGNIZER=1']
      end
    end
  end
  ```
- Microphone and speech usage strings are already in `Info.plist`.

## Costs and ops
- **xp cloud brain.** When `ANTHROPIC_API_KEY` is set, messages the on-device engine doesn't understand go to Claude (`XP_MODEL`, default `claude-opus-5-5`, low effort). Common requests (add expense, totals, breakdowns, patterns, tips) never leave the phone. To cut cost, set `XP_MODEL=claude-haiku-5-5`. Rate limit: 20 messages per minute per user (`backend/routes/xp.js`).
- **Fonts** (Plus Jakarta Sans) download on first launch and are then cached. For a fully offline first launch, bundle the font files under `assets/google_fonts/`.
