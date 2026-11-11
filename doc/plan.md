# Plan: dynamic_notification_kit (greenfield) — live delivery tracking + minimal notifications

## Context

The target folder `/Users/intersamrt/Documents/Flutter-Projects/notificaton_kit` is empty; no prior package exists. The "upgrade" request therefore becomes building the full plugin from scratch: a base notification API plus animated delivery tracking and minimal mode, on Android (16 Live Updates / ProgressStyle / ongoing) and iOS (ActivityKit + WidgetKit, Dynamic Island). Priority: native correctness > unified API > visual quality > docs/tests throughout.

Toolchain verified: Flutter 3.47.8 / Dart 3.13.7, Xcode 26.5, JDK 17, Android SDK with platform 36 (needed for ProgressStyle). `ANDROID_HOME` unset — set via `local.properties`/`flutter config`.

## Architecture

Flutter plugin (`flutter create --template=plugin --platforms=android,ios`), single MethodChannel `dynamic_notification_kit` + EventChannel for native events (action taps, activity ended, push-token).

### Dart (`lib/`)

- `src/models/`: `DeliveryState` (validated; `toMap/fromMap`, `copyWith`), `DeliveryVehicle`, `DistanceUnit`, `DeliveryRoute`/`GeoPoint`, `DynamicIcon`, `DynamicText`, `DynamicProgress`, `CompactNotificationContent`, `CompactNotificationLayout` (+ fallback rules), `DynamicNotificationRequest`, `DynamicNotificationMode` (incl. `minimal`), `DynamicNotificationCapabilities`.
- `src/templates/`: sealed `DeliveryTemplate` base; `DeliveryTrackingTemplate`, `CompactDeliveryTemplate`, `AnimatedRouteTemplate`, `DriverApproachingTemplate`, `DeliveryCompletedTemplate`. Templates are pure presentation config → serialize to one `template` map; all share `DeliveryState` and one update path.
- `src/delivery/`: `DeliveryController` (returned by `startDelivery`) with `update(progress:…)`, `update(state:)`, `updateLocation(lat,lng,route)`, `complete()`, `end()`. Internals:
  - `RouteProjector`: nearest-segment projection onto polyline (equirectangular local projection), cumulative-length progress, monotonic clamp.
  - `GpsSmoother`: reject accuracy/jump outliers, exponential smoothing; missing GPS → keep last progress.
  - `UpdateGate`: timestamp ordering (drop older `updatedAt`), dedup (no change in rounded progress/ETA/status), throttle (min interval, trailing-edge coalescing), post-completion lock, failure retry with backoff, error stream (`UpdateResult`, `DynamicNotificationException` with codes).
  - Interpolation: Dart sends `fromProgress`/`toProgress`/`animationMs`; native renders the transition (no high-frequency redraw). Reduced-motion flag passed through.
- `DynamicNotification` static facade: `start`, `update`, `end`, `startDelivery`, `getCapabilities`, `requestPermission`, `diagnose()` (reports missing manifest/Info.plist/widget-extension config), events stream.
- Capability fallback resolution in Dart (`PresentationResolver`) so behavior is testable without native.

### Android (`android/`, Kotlin, compileSdk 36)

- `DynamicNotificationKitPlugin` (MethodCallHandler, ActivityAware for POST_NOTIFICATIONS request), `NotificationEngine`, `ChannelManager`.
- Delivery rendering: API 36 → `Notification.ProgressStyle` with `ProgressStyle.Segment`s (completed/remaining colors), `Point`s (origin/destination), `setProgressTrackerIcon` (vehicle icon moves with progress), `setRequestPromotedOngoing(true)` + `shortCriticalText` (ETA chip) for Live Updates, checking `NotificationManager.canPostPromotedNotifications()`. Fallbacks: API <36 → ongoing notification with `RemoteViews`/`setProgress` + vehicle emoji/icon in custom collapsed/expanded layouts; API <33 → no runtime permission.
- Minimal mode: small icon + short title/text, `setOngoing`, `setOnlyAlertOnce`, optional `setUsesChronometer`/countdown, `setVisibility`; Live Update `shortCriticalText` when eligible. No claim of custom status-bar text.
- Vehicle icons as vector drawables; bitmap rendering for tracker icon; update only via event-driven `notify` with same id (no animation loops).
- Manifest: `POST_NOTIFICATION`, `POST_PROMOTED_NOTIFICATIONS`, `FOREGROUND_SERVICE` not needed (documented).

### iOS (`ios/`, Swift, podspec iOS 13+, runtime-gated 16.1+/17.2)

- Plugin class + `LiveActivityManager` using `Activity<DeliveryAttributes>` / `MinimalAttributes`, `ActivityContent` with `staleDate`, `update/end(dismissalPolicy)`, `activityStateUpdates` → events, push-token events, `areActivitiesEnabled` check.
- Shared `Codable` `DeliveryContentState` matching Dart map.
- `ios_widget_template/` (copied into the host app's Widget Extension; plugin pods can't host the extension): `DeliveryLiveActivity.swift` with `ActivityConfiguration`: Lock Screen (route line, moving vehicle via `GeometryReader` offset + `.animation`/`contentTransition`, origin/destination, status, ETA, `Text(timerInterval:)`), Dynamic Island expanded/compact/minimal. Reduced motion via `@Environment(\.accessibilityReduceMotion)`.
- Capabilities: iOS version, `areActivitiesEnabled`, Dynamic Island = device model heuristic (documented as heuristic), fallback to local `UNNotification` when Live Activities unavailable.
- Respect budget limits: native-side min-interval guard; report `ActivityAuthorizationError`s.

### Example app (`example/`)

Interactive screens: delivery simulator (slider + auto-drive along sample route, GPS-noise toggle, out-of-order injection), minimal notification demo (text/countdown/progress), capabilities/diagnostics page. Includes iOS Widget Extension target (copy of template) and `NSSupportsLiveActivities` plist key.

## One-command setup CLI (`bin/setup.dart`)

Goal: a developer adds the package, runs one command, and native config is done. Run as `dart run dynamic_notification_kit:setup [--android] [--ios] [--widget] [--dry-run] [--revert] [--check]`.

- **Idempotent + safe**: parses and patches (never blindly appends), skips what already exists, writes `.bak` backups, `--dry-run` prints a diff, `--revert` restores backups, `--check` exits non-zero if config is missing (usable in CI; same logic backs `DynamicNotification.diagnose()`).
- **Android patches**:
  - `android/app/src/main/AndroidManifest.xml`: add `POST_NOTIFICATIONS`, `POST_PROMOTED_NOTIFICATIONS`, (optional `VIBRATE`), no foreground-service perms.
  - `android/app/build.gradle(.kts)`: ensure `compileSdk >= 36`, `minSdk >= 21`, core library desugaring only if required.
  - Copies default vehicle/notification small-icon drawables into `res/drawable` if absent.
- **iOS patches**:
  - `ios/Runner/Info.plist`: `NSSupportsLiveActivities = true`, `NSSupportsLiveActivitiesFrequentUpdates` (opt-in flag), `NSUserNotificationsUsageDescription`-style description where relevant.
  - `ios/Podfile`: platform `ios 16.1`+ (min bump flagged and confirmed via prompt/`--yes`).
  - **Widget extension**: copies `ios_widget_template/` into `ios/DeliveryLiveActivity/` (Swift views, `Info.plist` with `NSExtensionPointIdentifier=com.apple.widgetkit-extension`, shared `DeliveryAttributes.swift`), and adds the Xcode target + embed phase + shared App Group via the `xcodeproj` Ruby gem helper (`tool/add_widget_target.rb`, invoked by the script). If the gem/Xcode isn't available, falls back to printing exact 5 manual steps (Xcode → New Target → Widget Extension, include Live Activity, add files) — never claims success it didn't achieve.
- Prints a final checklist: ✅ done / ⚠️ manual (e.g. enabling Push capability, signing team for the extension).
- Tested: Dart unit tests run the patchers against fixture manifests/plists/Podfiles/pbxproj (already-patched, missing-keys, Kotlin-DSL gradle, malformed file → clear error).

## Clean showcase + test example app (`example/`)

Replaces ad-hoc demo screens with a tidy, copy-paste friendly structure:

- `example/lib/main.dart` — bottom-nav shell with 3 tabs: **Delivery**, **Minimal**, **Diagnostics**.
- `example/lib/showcase/` — one small file per template (`delivery_tracking_demo.dart`, `compact_delivery_demo.dart`, `animated_route_demo.dart`, `driver_approaching_demo.dart`, `delivery_completed_demo.dart`, `minimal_demo.dart`), each ≤ ~80 lines, self-contained, exactly what the README quotes.
- `example/lib/simulator/` — reusable `DeliverySimulator` (drives a sample route at adjustable speed; toggles for GPS noise, dropouts, out-of-order packets, failure injection) so every template can be tested in the real notification surface with one tap.
- Diagnostics tab shows `getCapabilities()` + `diagnose()` results (green/amber/red rows) and a "Request permission" button.
- Preview cards in-app render each template's Flutter-side mock for visual reference only, labelled "preview — real surface is the system notification".
- Integration test (`example/integration_test/`) drives start → update → complete via the simulator on emulator; golden tests for preview cards.
- `example/` is generated by running the setup script on a clean app (dogfooding it), so the example proves the script works.

## Tests (`test/`)

Unit: `DeliveryState` validation, `RouteProjector`, `GpsSmoother`, `UpdateGate` (throttle/dedup/order/completed), template serialization, fallback resolver, controller with a mocked MethodChannel (start/update/location/ETA/status/complete/post-complete reject/invalid coords/missing GPS), minimal mode (create/update text/countdown/progress/mode switch/unsupported fallback/permission denied/termination). Native: Kotlin unit tests for builder selection by SDK; XCTest for state decoding. Device validation matrix documented and labelled emulator vs physical (I can only verify builds/emulator here; physical Dynamic Island and Android 16 Live Update behavior must be user-tested and will be reported as such).

## Docs

README (platform matrix, setup, permissions, limitations, GPS integration, fallbacks, complete sample) + `doc/` files listed in the request; screenshots: generated from simulator/emulator where possible, else clearly marked placeholders (no fabricated screenshots). CHANGELOG, LICENSE.

## Phases

1. Scaffold + Dart models/templates/controller/gate/projector + unit tests (`flutter analyze`, `flutter test`).
2. Android native + Kotlin tests; `flutter build apk` of example.
3. iOS native + widget template + example extension; `flutter build ios --no-codesign` / simulator build.
4. Example app, docs, final analyze/test/build run; honest report of what was/wasn't device-verified.

## Verification

`flutter analyze`, `flutter test`, `cd example && flutter build apk --debug`, `flutter build ios --simulator --no-codesign`, run on Android emulator (API 36) and iOS simulator (Dynamic Island model, e.g. iPhone 16 Pro) for visual check; physical-device checks flagged to the user.
