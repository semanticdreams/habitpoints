# HabitPoints

A lightweight habit tracker in flutter that awards points per completion, backed by a local SQLite database.

## What’s In This Repo

- Flutter app source: `lib/` (current entry point: `lib/main.dart`)
- Tests: `test/`
- Platform targets: `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/`

## Quick Start

Prerequisites: Flutter SDK (see `pubspec.yaml` for the supported Dart range) and a configured device/emulator.

```bash
flutter pub get
flutter run
```

To run on web:

```bash
flutter run -d chrome
```

## Common Commands

```bash
flutter analyze     # static analysis (lints in analysis_options.yaml)
flutter test        # run tests in test/
dart format .       # format Dart code
```

## Android Release (APK)

This repo includes a small `Makefile` wrapper:

```bash
make build          # builds a release APK
make install        # installs via adb (device/emulator required)
```

APK output (default): `build/app/outputs/flutter-apk/app-release.apk`.
