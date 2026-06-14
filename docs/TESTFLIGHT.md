# Releasing to TestFlight

The `testflight` job in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)
builds a signed Release archive of the iOS parent app and uploads it to
TestFlight. It runs **only on version tags** (`v*`), after the normal CI gates
and the unsigned `build-ios` job pass.

```
git tag v1.0.0
git push origin v1.0.0
```

Each upload uses:
- **Version** (`CFBundleShortVersionString`) = the tag without the `v` (e.g. `1.0.0`)
- **Build number** (`CFBundleVersion`) = the GitHub Actions run number (always unique/increasing)
- `ITSAppUsesNonExemptEncryption = NO` so the build skips the export-compliance prompt

## One-time setup (you must do this — it needs your Apple account)

### 1. Create the app record in App Store Connect
App Store Connect → **Apps → +** → New App.
- Platform: iOS
- Bundle ID: **`com.ticktrust.siwa`** (the registered App ID with Sign in with Apple)
- Name / Primary language / SKU as you like

A build can't be uploaded until this record exists.

### 2. Distribution certificate + provisioning profile
- Create an **Apple Distribution** certificate (Developer portal → Certificates) and
  export it as a `.p12` (with a password) from Keychain Access.
- Create an **App Store** provisioning profile for `com.ticktrust.siwa` and download
  the `.mobileprovision`.

### 3. App Store Connect API key (used for the upload)
Users and Access → **Integrations → App Store Connect API** → generate a key with
the **App Manager** role. Download the `.p8` (one chance only). Note the **Key ID**
and **Issuer ID**.

### 4. Add the GitHub repository secrets
Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
| --- | --- |
| `IOS_DIST_CERT_P12_BASE64` | `base64 -i dist.p12` (the distribution cert) |
| `IOS_DIST_CERT_PASSWORD` | the password you set when exporting the `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | `base64 -i profile.mobileprovision` |
| `APPSTORE_API_KEY_ID` | the API Key ID (e.g. `3KJ6787RDP`) |
| `APPSTORE_API_ISSUER_ID` | the API Issuer ID (a UUID) |
| `APPSTORE_API_PRIVATE_KEY_BASE64` | `base64 -i AuthKey_XXXX.p8` |

> On macOS, `base64 -i <file>` prints the base64; pipe to `pbcopy` to copy it.

## Notes
- The certificate is imported into a throwaway keychain that's deleted after the job.
- The job does **not** run on normal pushes to `main`, so it never uploads
  accidentally — only when you push a `v*` tag.
- If TestFlight reports a duplicate build number, it's because a tag was re-run;
  push a new tag (the build number tracks the run number).
