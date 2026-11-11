# Validation status

| Check | Status |
| --- | --- |
| `flutter analyze`, `flutter test` (Dart units, setup patchers) | automated, passing |
| Kotlin unit tests (render path by SDK, formatting) | automated, passing |
| `flutter build apk --debug` (compileSdk 36) | built |
| `flutter build ios --simulator --no-codesign` with widget extension | built; installs and launches on iPhone 16 Pro simulator |
| Live Activity rendering (lock screen / Dynamic Island) | **not verified** — needs manual run |
| Android 16 ProgressStyle / Live Update chip | **not verified** — needs API 36 device/emulator |
| Physical Dynamic Island, push tokens, budget limits | **not verified** — physical device |

Manual matrix: Android 16 (promoted on/off), Android 13–15, iPhone with/without Dynamic Island, Live Activities disabled, notification permission denied.
