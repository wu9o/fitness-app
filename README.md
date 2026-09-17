<p align="center">
  <img src="apps/movea/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" width="112" alt="Movea app icon">
</p>

<h1 align="center">Movea</h1>

<p align="center">
  A local-first, cross-platform companion for outdoor activity, strength training, recovery, and health.
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/wu9o/movea/actions/workflows/flutter-ci.yml"><img src="https://github.com/wu9o/movea/actions/workflows/flutter-ci.yml/badge.svg" alt="Flutter CI"></a>
  <a href="https://github.com/wu9o/movea/actions/workflows/app-build.yml"><img src="https://github.com/wu9o/movea/actions/workflows/app-build.yml/badge.svg" alt="App Builds"></a>
  <a href="https://github.com/wu9o/movea/releases"><img src="https://img.shields.io/github/v/release/wu9o/movea?include_prereleases" alt="Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/code-MIT-blue.svg" alt="MIT License"></a>
  <a href="third_party/workout-guide/LICENSE-ASSETS"><img src="https://img.shields.io/badge/exercise%20art-CC%20BY--SA%204.0-green.svg" alt="Exercise art license"></a>
</p>

> [!WARNING]
> Movea is an alpha project for personal use and experimentation. It is not a medical device and does not replace professional health or training advice.

## Product tour

<p align="center">
  <img src="docs/images/iphone-home.png" width="19%" alt="Movea home dashboard">
  <img src="docs/images/iphone-sports.png" width="19%" alt="Movea sports hub">
  <img src="docs/images/iphone-route-detail.png" width="19%" alt="Movea route details">
  <img src="docs/images/iphone-exercise-library.png" width="19%" alt="Movea exercise library">
  <img src="docs/images/iphone-exercise-detail.png" width="19%" alt="Movea exercise guidance">
</p>

These screenshots come from the current Flutter app running on an iPhone 16 Pro simulator. The displayed records are demo data.

## What Movea is building

| Area | Current experience |
| --- | --- |
| Outdoor activity | Run and ride recording, GPS quality, pause/resume, live distance, pace, and route traces |
| Routes | MapLibre + OpenFreeMap rendering, saved routes, route following, deviation checks, and spoken/haptic cues |
| Training insights | Activity history, calendar, weekly reports, load trends, heart-rate charts, and personalized zones |
| Strength training | 302 searchable exercises, 906 illustration frames, reusable workout plans, timers, sets, and rest intervals |
| Health | HealthKit imports, sleep stages and quality, weight, recovery context, and source-aware records |
| Data safety | Local-first storage, integrity snapshots, diagnostics, and AES-256-GCM encrypted backup/restore |
| Apple Watch | Native workout-session source is present; formal target integration and paired-device validation remain |
| Android | Shared Flutter experience is planned; Android location and Health Connect adapters remain in progress |

## Design principles

- Local data is the source of truth; cloud storage is an optional encrypted backup.
- Recording a workout must work offline.
- Real health data and demo data must be unmistakably separated.
- Shared domain logic comes before platform-specific UI.
- Every supported form factor receives its own interaction and layout review.
- Maps help the user understand movement; they should not overwhelm the route.

## Platform plan

| Platform | Intended role | Implementation |
| --- | --- | --- |
| iPhone | Complete activity, route, training, and health experience | Flutter |
| iPad | Split-view history, route planning, and health analysis | Adaptive Flutter UI |
| macOS | History, trend analysis, planning, and data management | Flutter macOS |
| Android | Activity, route, training, and health experience | Flutter |
| Apple Watch | Fast workout controls, heart rate, and location | Native watchOS / SwiftUI |

## Architecture

```text
                   +------------------------+
                   |   Shared domain layer  |
                   | activity / route /     |
                   | health / backup        |
                   +-----------+------------+
                               |
              +----------------+----------------+
              |                                 |
   +----------v-----------+          +----------v-----------+
   | Flutter applications |          | Native Watch module  |
   | iOS / iPadOS / macOS |          | workout / sensors    |
   | Android              |          | Watch Connectivity   |
   +----------+-----------+          +----------+-----------+
              |                                 |
   +----------v---------------------------------v-----------+
   | Platform adapters: location, health, storage, speech   |
   +--------------------------------------------------------+
```

- Flutter and Dart provide the shared navigation, UI, domain models, and backup flows.
- Platform adapters isolate HealthKit, Health Connect, Core Location, and Android location services.
- MapLibre renders an open map stack without embedding a commercial map credential.
- GitHub private repositories are treated as encrypted backup destinations, not realtime databases.
- The first SwiftUI prototype remains in `legacy/swiftui-prototype` as an interaction reference.

More detail: [product](docs/product.md) · [architecture](docs/architecture.md) · [roadmap](docs/roadmap.md)

## Quick start

Requirements: Flutter 3.47 (or a compatible stable version), Dart 3.3+, and Xcode for Apple builds.

```bash
git clone https://github.com/wu9o/movea.git
cd movea/apps/movea
flutter pub get
flutter analyze
flutter test
flutter run
```

For simulator GPS playback and platform-specific checks, read [development.md](docs/development.md) and [testing-gps.md](docs/testing-gps.md).

## Continuous integration

- **Flutter CI** runs formatting, static analysis, and tests for the app and shared packages.
- **App Builds** produces an Android debug APK plus iOS Simulator and macOS debug bundles.
- **Preview Release** publishes persistent downloadable assets whenever a `v*` tag is pushed.
- Release assets are development previews: a development-signed Android APK, an iOS Simulator bundle, and an unsigned macOS app. They are not App Store or Play Store packages.

Download the latest preview from [GitHub Releases](https://github.com/wu9o/movea/releases). iOS device and store distribution will be added only after signing and provisioning are configured.

## Repository layout

```text
movea/
├── apps/movea/                 # Flutter application
├── packages/
│   ├── movea_domain/           # Activity, route, health, and record models
│   ├── movea_data/             # Local storage, encrypted backup, sync contracts
│   └── movea_design/           # Design tokens and responsive components
├── watchos/MoveaWatch/         # Native Apple Watch companion source
├── docs/                       # Product, architecture, roadmap, and QA guides
├── tooling/                    # GPS playback and development utilities
├── third_party/                # Attributions and imported exercise assets
└── legacy/swiftui-prototype/   # Historical prototype
```

## Roadmap

Near-term work focuses on:

1. paired-device validation for the Apple Watch workout flow;
2. more robust GPS recording and route guidance on real devices;
3. platform-native health adapters for Android;
4. encrypted GitHub backup conflict handling and recovery UX;
5. accessibility, localization, performance, and platform-specific visual QA.

See [the detailed roadmap](docs/roadmap.md) for the current engineering sequence.

## Privacy and security

Activity and health records remain on the device by default. Tokens, plaintext health exports, signing material, and personal route data must never be committed. Backups are encrypted on-device before upload.

Please report vulnerabilities privately through [GitHub Security Advisories](https://github.com/wu9o/movea/security/advisories/new), not through public issues. See [SECURITY.md](SECURITY.md).

## Contributing

Bug reports, product discussions, and focused pull requests are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), and remove personal location or health data from all screenshots and logs.

Movea source code is available under the [MIT License](LICENSE). Exercise illustrations derived from [Workout Guide](https://github.com/bryllim/workout-guide) are provided under [CC BY-SA 4.0](third_party/workout-guide/LICENSE-ASSETS). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for map and runtime attribution.

<p align="center"><strong>Movea 0.1.0 · Trailhead / 起跑线</strong></p>
