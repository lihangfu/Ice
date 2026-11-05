# Development and releases

[Back to the project](../README.en.md) · [简体中文](development.md) · **English**

This guide covers local builds, validation, releases, signing and notarization for developers and maintainers. Run all commands from the repository root.

## Build and run locally without Xcode

Requires macOS 14 or later and Command Line Tools with Swift 6 or later. Install
Apple's tools with `xcode-select --install` if needed. Full Xcode is not required.
The first build needs network access to download the dependencies pinned by the
existing Xcode `Package.resolved`; later builds reuse the SwiftPM cache.

```sh
./scripts/run-app.sh
```

This builds the current source for your Mac's architecture, packages and locally
signs `build/Ice.app`, then opens it. Quit a running `build/Ice.app` before rebuilding.
To build without launching, or to make an optimized local build:

```sh
./scripts/build-app.sh
./scripts/build-app.sh release
```

Use the packaged `.app`, not `swift run`: Ice needs its bundle metadata, icons,
translations and embedded Sparkle framework. The scripts use Python 3 supplied
with Command Line Tools and built-in macOS packaging tools. They don't install or
replace `/Applications/Ice.app`. The local app shares Ice's bundle identifier and
preferences; macOS may ask you to grant Accessibility and Screen Recording again
for the locally signed binary. Quit any other Ice instance before using it.

Local builds disable online updates so a release cannot replace your development
app. They use ad-hoc signing and are not notarized. Distribution continues to use
the Xcode release workflow below, including its update-signing key.

After building, verify the real bundle and localization:

```sh
python3 Tests/run-build-tests.py
bash Tests/run-localization-tests.sh
```

The bundle check runs the actual executable before migrations or permission
requests. It verifies assets, image scales, light/dark colors, translations,
metadata, signature and relocation, and checks that missing resources fail.
It also checks legacy appearance migration. It does not exercise menu bar
manipulation or grant macOS permissions. To render the appearance editor and
general settings content at small, medium, and large sidebar sizes in both themes,
and verify Ice Bar appearance and icons:

```sh
build/Ice.app/Contents/MacOS/Ice --validate-appearance build/appearance-validation
```

These are component checks, not settings-window chrome acceptance. Validate the
production SwiftUI settings scene separately:

```sh
build/Ice.app/Contents/MacOS/Ice --validate-settings-scene build/settings-scene-validation
```

This opens the real settings window after scene startup, skips migrations,
permission requests and normal menu bar setup, and uses the default settings model.
It captures all six panes in light/dark, scroll and return-to-top states, wide windows
and shrinking back to minimum width. It checks that scrolling does not repaint the
sidebar titlebar and that the window geometry observer cancels and restores its
configuration when detached. Appearance, frame and pane are restored before exit.
`scene-properties.json` records native toolbar geometry and actual activation state;
material activity is not forced. Other macOS versions and accessibility preferences
still need manual checks.

For negative controls, append `--opaque-settings-window-control` to re-enable
the retired window-wide opacity flag, or `--compact-settings-toolbar-control` for
the wrong toolbar configuration. Both are expected to exit unsuccessfully.
The retired `--original-settings-titlebar-control` reports this replacement entry.

The appearance validation also checks monochrome icon rendering, colored badge
preservation and transparent cutouts, and captures live status item comparisons.
The settings layout checks also cover native drawing, drag preview colors,
disabled-item dimming, hit testing and placeholder geometry without moving menu
items. These icon captures require screen recording access. To verify that the contrast
check catches the original white-on-light failure, run the negative control
(expected to exit unsuccessfully):

```sh
build/Ice.app/Contents/MacOS/Ice --validate-appearance build/icon-negative --original-ice-bar-icons-control
```

For the equivalent settings layout negative control, use
`--original-layout-icons-control` instead.

## Releasing

The [Release Ice workflow](../.github/workflows/release.yml) builds and publishes
`Ice.zip` and an `appcast.xml` containing its update signature to the repository
where the tag is pushed. Releases for this project are published to
[lihangfu/Ice](https://github.com/lihangfu/Ice/releases).

### One-time update signing setup

Sparkle requires a free Ed25519 update-signing key pair in addition to the Apple
signing identity below. Using the tools in the
[Sparkle 2.6.4 distribution](https://github.com/sparkle-project/Sparkle/releases/tag/2.6.4),
run these commands from the extracted distribution directory:

```sh
umask 077
./bin/generate_keys --account lihangfu-Ice
./bin/generate_keys --account lihangfu-Ice -p
./bin/generate_keys --account lihangfu-Ice -x "$HOME/ice-sparkle-private-key.txt"
```

In the repository's **Settings > Secrets and variables > Actions**, configure:

- Repository variable `SPARKLE_PUBLIC_ED_KEY`: the public key printed by `-p`.
- Repository secret `SPARKLE_PRIVATE_ED_KEY`: the contents of the exported private-key file.

Keep the private key backed up securely and outside this repository. Reuse this
key pair for future releases; changing it can prevent installed builds from
updating. Local builds must also pass `SPARKLE_PUBLIC_ED_KEY` to `xcodebuild`.
The workflow checks for missing keys before building and refuses to publish an
unsigned update archive or a feed generated with mismatched keys.

### One-time Apple signing and notarization setup

An active Apple Developer Program membership and a Developer ID Application
certificate with its private key are required. In Keychain Access, export the
identity from **login > My Certificates** as a password-protected `.p12` file.
Keep it outside this repository. Convert it to Base64 with
`base64 -i /path/to/ice-signing.p12 | pbcopy` and configure these repository
**Secrets** in **Settings > Secrets and variables > Actions**:

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64-encoded `.p12` containing the certificate and private key |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_TEAM_ID` | The certificate's 10-character Apple Developer Team ID |
| `APPLE_ID` | Apple Account used for notarization, with access to that team |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password generated at [Apple Account](https://account.apple.com/) |

The workflow imports the identity and Apple's Developer ID G2 intermediate
certificate into a temporary keychain on the GitHub-hosted runner. It requires
exactly one valid Developer ID Application identity for the configured team and
validates notarization credentials before building. The `.p12` file is removed
after import; the keychain, including its notarization credentials, is deleted
when the job finishes, including on failure. Missing or invalid credentials fail
the release; there is no unsigned publishing fallback.

Run the release guard checks locally with Python 3 and macOS's system Ruby
(using its bundled YAML and JSON libraries; no Python packages are required):

```sh
python3 Tests/run-release-tests.py
```

These checks exercise admission, timeout diagnostics, and recovery with fixture
credentials and notarization results. System `ditto` and `tar` verify artifact
round trips, executable permissions, and symbolic links. They do not import a real
private key, archive a real app, or contact Apple's notarization service. The release
job runs them before using the configured credentials.

### Publish a release

Commit and push the workflow before creating a release tag. The tagged commit
must contain the workflow. Use a new tag in the format `vMAJOR.MINOR.PATCH`:

```sh
git tag v0.11.15
git push origin v0.11.15
```

The release job uses GitHub's standard macOS 15 Intel runner (`macos-15-intel`)
with Xcode 16.4 to archive and export a Release app for both Apple Silicon and Intel Macs.
The app version comes from the tag; its build
number comes from the GitHub Actions run number. These values are set only for the CI build.
The Xcode archive/export workflow signs the app and Sparkle's nested helpers with
Developer ID and enables Hardened Runtime. It submits the exported app to Apple,
waits up to 30 minutes while displaying `notarytool` progress, then queries the
latest status and attempts to retrieve Apple's log. The run summary includes the
submission ID, exit codes, and status. Only an `Accepted` result allows ticket
stapling, final `Ice.zip` generation, and publishing. A timeout fails the job;
Apple continues processing the submission.

Before publishing, the workflow extracts `Ice.zip` and checks the executable,
both architectures, the code signature and expected Developer ID team, the
stapled ticket, Gatekeeper acceptance, the app version, and the update settings.
It then uses the pinned Sparkle package's tools to sign the archive, generate the
appcast, and verify the update signature and metadata.

The workflow uses GitHub's `GITHUB_TOKEN` with `contents: write` to publish and
`actions: read` to inspect the recovery source and download its artifacts.
Enable GitHub Actions in the repository's Actions tab if it
is disabled.

### Resume an existing notarization submission

Before waiting for notarization, the initial release saves an
`ice-signed-<run_id>-<run_attempt>` artifact for 30 days. It contains the original
signed app archive, build number, source commit, archive SHA-256, submission ID,
and the Sparkle tools used by that build. Submission has a five-minute limit;
even if it fails, the workflow attempts to save the prepared signed archive.
It contains no signing private keys or
notarization credentials. Status responses and available Apple logs are saved
separately as `ice-notarization-<run_id>-<run_attempt>`.

After a timeout, inspect the run summary and diagnostics. To continue the same
submission, open **Actions > Release Ice > Run workflow**, select the default
branch containing the recovery workflow, and enter these values from the original
run's summary:

| Input | Value |
| --- | --- |
| `tag` | Original release tag, such as `v0.12.2` |
| `source_run_id` | Run that first built and saved the signed artifact; its URL contains `/runs/<id>` |
| `source_run_attempt` | Attempt that saved the artifact, usually `1` for the initial run |
| `submission_id` | Apple notarization UUID returned by that same attempt |

Recovery downloads the original artifact and verifies the repository, workflow,
tag commit, run and attempt, submission ID, and archive checksum before waiting
for notarization and applying the existing release checks. It does not rebuild,
re-sign, or resubmit the app. The app and update feed retain the original build
number. Recovery requires no `.p12` private key; it still requires notarization
credentials, the original Apple team, and matching Sparkle update keys.

If recovery times out again, use the same original run inputs. If Apple returns
`Invalid`, use its diagnostic log to fix the issue and submit a new build.
Expired or deleted artifacts, moved tags, and missing submission IDs fail recovery
without falling back to a new build. Older runs that saved no signed artifact
cannot be recovered through this entry point. The archived app has no stapled
ticket yet and must not be distributed as a finished release.

To roll back recovery support, revert the workflow and corresponding checks. This
does not cancel submissions Apple has received or alter published releases.
Cross-run downloads, Apple notarization, ticket stapling, and Gatekeeper acceptance
still require validation on a real runner.

### Updates and release recovery

Automatic and manual update checks both read this repository's latest release's
`appcast.xml` and download its signed `Ice.zip`.
Changing from ad-hoc to Developer ID signing may require users to grant
Accessibility and Screen Recording access again.

Install a release manually if the installed app uses a different update feed or
signing key. To test the feed, use two Release builds from this repository: check
for updates manually in the older build, then enable automatic checks and downloads and
confirm that the newer version is offered and installed.

Existing releases are not overwritten. If publishing fails, inspect the release
for a partially created draft. If the saved artifact is available, use the recovery
entry point above to avoid resubmitting the app. To withdraw a bad build,
remove its release through GitHub; publish corrections under a new tag.
To recover from a broken release, manually install a known-good build from this
repository, keeping the same signing key, then publish a corrected build with a
higher build number. A source rollback alone does not change already installed apps.
To roll back this signing integration, revert the workflow change before creating
a new tag; older workflow revisions produce ad-hoc builds without notarization.
Rotate the `.p12` secrets before the Developer ID certificate expires, keeping the
same team and Sparkle update-signing key. An Apple identity change does not replace
Sparkle's update-signing key.

## Appearance settings compatibility

Tint, shadow, border and shape use one shared configuration in both system
appearances. When upgrading from dynamic appearance settings, Ice preserves
the configuration active at the first launch and uses it for subsequent launches.
The separate light/dark editors and preview controls are no longer available.

Menu bar background blur customization is no longer provided. Existing blur
strength settings are ignored and omitted when appearance settings are saved.
Tint, shadow, border and shape settings remain available. Ice Bar continues to
use its native frosted background, following the system light/dark appearance.
