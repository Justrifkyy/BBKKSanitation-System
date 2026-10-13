# SISKARA Mobile

Flutter application for ship captains, pilots, and BBKK staff. Admin accounts
use the web portal.

## Android setup

Requirements:

- Flutter stable and Dart on `PATH`
- Android Studio with Android SDK, Android SDK Command-line Tools, and an
  Android emulator (or an Android phone with USB debugging enabled)
- Firebase app configuration generated for project `bbkk-9d446`

The Android application ID is `store.lycabyte.siskara`. Firebase configuration
is in `lib/firebase_options.dart` and `android/app/google-services.json`.
Do not replace these with service-account credentials.

After installing Android Studio, open **SDK Manager** and install the Android
SDK Platform and Build-Tools offered as recommended by Flutter. Then run:

```powershell
flutter doctor --android-licenses
flutter doctor -v
```

Create and start an emulator in Android Studio's **Device Manager**, or connect
an Android phone with USB debugging enabled. From `apps/mobile`:

```powershell
flutter pub get
flutter devices
flutter run --dart-define=SISKARA_API_BASE_URL=https://<deployed-web-host>/api
```

The API URL must point to the deployed SISKARA Next.js web app, not just a
domain serving a static or unrelated website. For local web development on the
Android emulator, start the web app on port 3000 and use:

```powershell
flutter run --dart-define=SISKARA_API_BASE_URL=http://10.0.2.2:3000/api
```

The Android debug manifest permits cleartext HTTP for local development only.
Release builds do not enable this setting. For a physical Android phone, use
the computer's reachable LAN IP instead of `10.0.2.2`, and ensure the phone can
reach port 3000.

Firebase initialization uses generated platform options. To reconfigure the
Android app after changing its application ID, run from this directory:

```powershell
flutterfire configure --project=bbkk-9d446 --platforms=android --android-package-name=store.lycabyte.siskara
```
