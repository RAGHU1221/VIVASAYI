# Flutter Mobile App Scaffold

## Setup

1. Install Flutter SDK
2. Run:
   ```bash
   flutter pub get
   ```

3. Launch the app:
   ```bash
   flutter run
   ```

   Use `API_BASE_URL` when the API is not reachable at `localhost:8000` from the target device:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
   ```

## Structure

- `lib/main.dart` — entry point
- `lib/src/app.dart` — theme and localization
- `lib/src/` — app features and modules
- `android/` — native Android platform project (applicationId `com.vivasayi.app`, minSdk 23)

## Building an APK

1. Install the Flutter SDK and make sure `flutter doctor` reports no Android toolchain issues.
2. From `flutter_app/`, run:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
   The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

Notes:
- `android/app/src/main/res/mipmap-*/ic_launcher.png` are 1x1 placeholder icons. Drop a real icon at `assets/images/app_icon.png` and run `flutter pub run flutter_launcher_icons` to generate proper launcher icons before publishing.
- The release build currently signs with the debug keystore (`android/app/build.gradle`). Before publishing to the Play Store, create a real signing key and `android/key.properties` (see the [Flutter signing guide](https://docs.flutter.dev/deployment/android#signing-the-app)) and update `buildTypes.release.signingConfig` accordingly.
