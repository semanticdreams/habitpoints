# Repository Guidelines

## Project Structure & Module Organization

- `lib/`: Dart/Flutter application code. Current entry point is `lib/main.dart` (UI + SQLite persistence).
- `test/`: Flutter tests (e.g., `test/widget_test.dart`).
- Platform folders: `android/`, `ios/`, `macos/`, `windows/`, `linux/`, `web/`. These are mostly generated; avoid editing unless you’re making platform-specific changes.
- Tooling/config: `pubspec.yaml` (dependencies), `analysis_options.yaml` (lints), `Makefile` (Android release helpers).

## Build, Test, and Development Commands

- `flutter pub get`: Install/update Dart/Flutter dependencies.
- `flutter run`: Run locally on a connected device/simulator (use `-d chrome` for web).
- `flutter analyze`: Static analysis (uses `flutter_lints` via `analysis_options.yaml`).
- `flutter test`: Run all tests in `test/`.
- `dart format .`: Format Dart code across the repo.
- `make build`: Build a release Android APK (`flutter build apk --release`).
- `make install`: Install the release APK via `adb` (requires Android SDK + a device/emulator).

## Coding Style & Naming Conventions

- Indentation: 2 spaces; keep lines readable and avoid deeply nested widgets where possible.
- Naming: `UpperCamelCase` for classes/widgets, `lowerCamelCase` for variables/functions, `snake_case.dart` for filenames.
- Prefer small, focused widgets and helpers. If `lib/main.dart` grows, split into feature files under `lib/` (e.g., `lib/db/`, `lib/widgets/`).

## Testing Guidelines

- Framework: `flutter_test`.
- Place tests in `test/` and name files `*_test.dart`.
- Add/adjust tests for behavior changes and bug fixes; keep tests deterministic (avoid wall-clock timing where possible).

## Commit & Pull Request Guidelines

- Commit messages follow a simple imperative style seen in history: `Add …`, `Update …`, `Fix …` (one change per commit when practical).
- PRs should include: a short description, any relevant issue links, and screenshots/screen recordings for UI changes.
- Before requesting review, run `flutter analyze`, `flutter test`, and format with `dart format .`.

