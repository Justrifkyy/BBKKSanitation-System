# ARJUNA Mobile

Flutter application for ship captains, pilots, and BBKK staff. Admin accounts
use the web portal.

## Android setup

Requirements:

- Flutter stable and Dart on `PATH`
- Android Studio with Android SDK, Android SDK Command-line Tools, and an
  Android emulator (or an Android phone with USB debugging enabled)
- Firebase app configuration generated for project `bbkk-9d446`

The Android application ID is `store.lycabyte.siskara` (kept unchanged so the
existing Firebase Android client configuration remains valid). Firebase configuration
is in `lib/firebase_options.dart` and `android/app/google-services.json`.
Do not replace these with service-account credentials.
The launcher and sign-in screen use the ARJUNA system logo and BBKK logo from
`assets/images/`.

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
flutter run --dart-define=ARJUNA_API_BASE_URL=https://<deployed-web-host>/api
```

The API URL must point to the deployed ARJUNA Next.js web app, not just a
domain serving a static or unrelated website. For local web development on the
Android emulator, start the web app on port 3000 and use:

```powershell
flutter run --dart-define=ARJUNA_API_BASE_URL=http://10.0.2.2:3000/api
```

The Android debug manifest permits cleartext HTTP for local development only.
Release builds do not enable this setting. For a physical Android phone, use
the computer's reachable LAN IP instead of `10.0.2.2`, and ensure the phone can
reach port 3000.

## Building smaller Android APKs

Avoid sharing `app-debug.apk` for normal installation; it contains debug
runtime data and native libraries for multiple device architectures. Build
optimized APKs split by architecture from this directory:

```powershell
flutter build apk --release --split-per-abi
```

The generated files are in `build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk` for most modern Android phones and tablets
- `app-armeabi-v7a-release.apk` for older 32-bit Android devices
- `app-x86_64-release.apk` for x86_64 emulators such as LDPlayer when configured
  with a 64-bit Android image

Send only the APK matching the recipient's device. The current Android release
build is signed with the development debug key in `android/app/build.gradle.kts`;
it is suitable for internal testing, not public distribution. Configure a
private release keystore before distributing the app publicly.

If you need one APK for devices with unknown architectures, run
`flutter build apk --release`. This creates `app-release.apk`; it is larger
than each split APK because it includes all supported architectures, but is
still much smaller than a debug APK.

During account security setup, users can draw a signature in the app or select
a PNG/SVG file up to 512 KB. The API validates the uploaded file type before it
is saved to the private Cloudflare R2 bucket. Evidence photos and videos use
the same private bucket; Firestore stores only protected object paths and
metadata. Saved signatures can be replaced from the signature settings screen.
The **Keluar** action returns to the login screen without saving the setup.

When deploying changes to submission or signature APIs, deploy the web app and
publish the Firestore rules in `firebase/firestore.rules` as well as installing
the updated mobile APK.

Firebase initialization uses generated platform options. To reconfigure the
Android app after changing its application ID, run from this directory:

```powershell
flutterfire configure --project=bbkk-9d446 --platforms=android --android-package-name=store.lycabyte.siskara
```

The `SISKARA_API_BASE_URL` define is still accepted as a backwards-compatible
alias, and the Android application ID remains tied to the existing Firebase
configuration. These are internal integration identifiers, not the app's
display name.

## Mobile navigation and evidence

After signing in and completing the initial security setup, users land on the
dashboard. It summarizes screening/review activity, links to role-specific
screening or review tasks, history, and profile, and provides access to update
the digital signature. The compact bottom navigation keeps Dashboard, the
role-specific work area, History, and Profile available.

Every checklist item requires a photo, regardless of its answer. Capture a
photo with the camera; evidence capture requires location permission and an
enabled location service so GPS coordinates and capture time can be stored
with the media. A compact local preview is shown before submission.

Network, Firebase, API, device permission, and data-format errors are translated
to actionable messages in the app. API validation/conflict responses retain
their server-provided explanation; authentication and permission errors explain
how to proceed; HTTP 5xx responses show the status and advise retrying later.
Unexpected technical details are not shown to the user.

General voyage data is grouped by vessel/aircraft identity, route and schedule,
and passenger/crew details. Dates and times use pickers; numeric fields reject
invalid, negative, and non-integer counts before submission.
