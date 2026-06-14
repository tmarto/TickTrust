# Releasing to TestFlight

The `testflight` job in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)
builds a signed Release archive of the iOS parent app and uploads it to
TestFlight. It runs **only on version tags** (`v*`), after the normal CI gates
and the unsigned `build-ios` job pass.

```
git tag v1.0.0
git push origin v1.0.0
```

Signing is **API-key cloud signing**: Xcode creates/fetches the distribution
certificate and provisioning profile automatically using your App Store Connect
API key (`-allowProvisioningUpdates`), so there is no certificate or profile to
manage manually.

Each upload uses:
- **Version** (`CFBundleShortVersionString`) = the tag without the `v` (e.g. `1.0.0`)
- **Build number** (`CFBundleVersion`) = the GitHub Actions run number (always unique/increasing)
- `ITSAppUsesNonExemptEncryption = NO` so the build skips the export-compliance prompt

## One-time setup

### 1. Create the app record in App Store Connect — done
App Store Connect → Apps → **TickTrust** (`com.ticktrust.siwa`, App ID `6780248452`).

### 2. App Store Connect API key
Users and Access → Integrations → **App Store Connect API**. If access isn't
enabled yet, click **Request access** first (account holder only). Then generate
a key with the **App Manager** role, download the `.p8` (one chance only), and
note the **Key ID** and **Issuer ID**.

### 3. GitHub repository secrets
Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
| --- | --- |
| `APPSTORE_API_KEY_ID` | the API Key ID (e.g. `A57FN7S97G`) |
| `APPSTORE_API_ISSUER_ID` | the API Issuer ID (a UUID) |
| `APPSTORE_API_PRIVATE_KEY_BASE64` | `base64 -i AuthKey_XXXX.p8` (the downloaded `.p8`) |

> On macOS, `base64 -i AuthKey_XXXX.p8 | pbcopy` copies the value ready to paste.

### 4. (For EU public distribution) Provide trader status
Apps page → the EU Digital Services Act banner. Not required to upload a build
to TestFlight for internal testing, but required before EU public release.

## Notes
- The API key must have at least the **App Manager** role to create signing
  assets and upload builds.
- The job does **not** run on normal pushes to `main`, so it never uploads
  accidentally — only when you push a `v*` tag.
- If TestFlight reports a duplicate build number, push a new tag (the build
  number tracks the run number).
