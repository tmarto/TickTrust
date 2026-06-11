# ZeitBank

Parental control app that hard-terminates kids' games/apps on a schedule. Bypass-proof.

## Features

- **Parent app** — select child, device, app limits (per-app daily minutes)
- **Kill engine** — countdown warnings at 2min / 1min / 10sec, then hard kill
- **Time credits** — bonus minutes granted by parent, debt carried to next day
- **KMP shared logic** — one codebase for Android + iOS business rules

## Architecture

```
ZeitBank/
├── shared/          # Kotlin Multiplatform — models, services, logic
├── androidApp/      # Android (Jetpack Compose)
└── iosApp/          # iOS (SwiftUI)
```

## Setup

### Prerequisites

- JDK 17+
- Android Studio Ladybug or later
- Xcode 15.4+ (macOS only, for iOS)

### Build Android

```bash
./gradlew :androidApp:assembleDebug
```

APK at `androidApp/build/outputs/apk/debug/`

### Build iOS

```bash
./gradlew :shared:assembleZeitBankSharedReleaseXCFramework
xcodebuild -project iosApp/iosApp.xcodeproj -scheme iosApp -configuration Release \
  -destination "generic/platform=iOS Simulator" build
```

### Run tests

```bash
./gradlew :shared:allTests
```

### Coverage report

```bash
./gradlew :shared:koverXmlReport
# Report at shared/build/reports/kover/report.xml
```

## CI/CD

GitHub Actions pipeline (`.github/workflows/ci.yml`):

| Job | Trigger | What it does |
|-----|---------|-------------|
| `lint-and-test` | every push/PR | ktlint + unit tests + 60% coverage gate |
| `integration-test` | after lint | Android emulator API 33 |
| `build-android` | after tests | release APK (obfuscated) |
| `build-ios` | after tests | unsigned IPA via xcodebuild |
| `release` | `v*` tags only | attaches APK + IPA to GitHub Release |

## License

MIT
