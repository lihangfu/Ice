<div align="center">
    <img src="Ice/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width=200 height=200>
    <h1>Ice</h1>
</div>

Ice is a powerful menu bar management tool. While its primary function is hiding and showing menu bar items, it aims to cover a wide variety of additional features to make it one of the most versatile menu bar tools available.

![Banner](https://github.com/user-attachments/assets/4423085c-4e4b-4f3d-ad0f-90a217c03470)

[![Download](https://img.shields.io/badge/download-latest-brightgreen?style=flat-square)](https://github.com/lihangfu/Ice/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS-blue?style=flat-square)
![Requirements](https://img.shields.io/badge/requirements-macOS%2014%2B-fa4e49?style=flat-square)
[![Sponsor](https://img.shields.io/badge/Sponsor%20%E2%9D%A4%EF%B8%8F-8A2BE2?style=flat-square)](https://github.com/sponsors/jordanbaird)
[![Website](https://img.shields.io/badge/Website-015FBA?style=flat-square)](https://icemenubar.app)
[![License](https://img.shields.io/github/license/jordanbaird/Ice?style=flat-square)](LICENSE)

> [!NOTE]
> Ice is currently in active development. Some features have not yet been implemented. Download the latest release [here](https://github.com/lihangfu/Ice/releases/latest) and see the roadmap below for upcoming features.

<a href="https://www.buymeacoffee.com/jordanbaird" target="_blank">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;">
</a>

## Install

### Manual Installation

Download the "Ice.zip" file from the [latest release](https://github.com/lihangfu/Ice/releases/latest) and move the unzipped app into your `Applications` folder.

### Homebrew

Install Ice using the following command:

```sh
brew install --cask jordanbaird-ice
```

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
manipulation or grant macOS permissions. To render the actual appearance editor
in both system themes without changing saved settings:

```sh
build/Ice.app/Contents/MacOS/Ice --validate-appearance build/appearance-validation
```

To exercise wallpaper processing and live menu bar composition without saving
settings (temporarily changes the visible menu bar background):

```sh
build/Ice.app/Contents/MacOS/Ice --validate-wallpaper-blur build/wallpaper-blur-validation
```

This checks fractional persistence, invalid input, blur texture reduction,
black/white foreground pixels, clipping and restoration, and saves screenshots.
It requires screen capture access. Without Accessibility authorization it calls
the production capture/drawing path directly and reports that menu discovery,
actual split geometry and menu interaction remain unverified.

## Releasing this fork

The [Release Ice workflow](.github/workflows/release.yml) builds and publishes
`Ice.zip` and an `appcast.xml` containing its update signature to the repository
where the tag is pushed. In this fork, releases are published to
[lihangfu/Ice](https://github.com/lihangfu/Ice/releases).

### One-time update signing setup

Sparkle requires a free Ed25519 update-signing key pair. An Apple Developer
certificate is not required for these ad-hoc builds. Using the tools in the
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

### Publish a release

Commit and push the workflow before creating a release tag. The tagged commit
must contain the workflow. Use a new tag in the format `vMAJOR.MINOR.PATCH`:

```sh
git tag v0.11.15
git push origin v0.11.15
```

The release job uses GitHub's standard macOS 15 Intel runner (`macos-15-intel`)
with Xcode 16.4 to build a Release app for both Apple Silicon and Intel Macs.
The app version comes from the tag; its build
number comes from the GitHub Actions run number. These values are set only for the CI build.
Before publishing, the workflow extracts `Ice.zip` and checks the executable,
both architectures, the code signature, the app version, and the update settings.
It then uses the pinned Sparkle package's tools to sign the archive, generate the
appcast, and verify the update signature and metadata.

No Apple certificates are required. The workflow uses the update-signing key
above to sign the archive and GitHub's `GITHUB_TOKEN` to publish the release with
`contents: write` permission. For a fork, enable GitHub Actions in the repository's
Actions tab if it is disabled.

These builds use ad-hoc signing, disable Hardened Runtime to allow Sparkle to
load, and are not notarized by Apple. macOS may block the first launch. Automatic
and manual update checks both read this fork's latest release's `appcast.xml` and
download its signed `Ice.zip`. The Homebrew cask still installs upstream Ice.

Install the first build with this update configuration manually. Existing builds
still use the upstream feed and key and cannot discover this fork's updates.
To test the new feed, use two Release builds from this fork: check for updates
manually in the older build, then enable automatic checks and downloads and
confirm that the newer version is offered and installed.

Existing releases are not overwritten. If publishing fails, inspect the release
for a partially created draft before rerunning the job. To withdraw a bad build,
remove its release through GitHub; publish corrections under a new tag.
To recover from a broken release, manually install a known-good build from this
fork, keeping the same signing key, then publish a corrected build with a higher
build number. A source rollback alone does not change already installed apps.

## Features/Roadmap

Settings show contextual explanations behind the circled question mark next to
each relevant setting's name. Hover to read the explanation, or activate the help
button with a click or keyboard to open it in a popover. Operational warnings and
status messages remain visible in the settings page.

### Menu bar item management

- [x] Hide menu bar items
- [x] "Always-hidden" menu bar section
- [x] Show hidden menu bar items when hovering over the menu bar
- [x] Show hidden menu bar items when an empty area in the menu bar is clicked
- [x] Show hidden menu bar items by scrolling or swiping in the menu bar
- [x] Automatically rehide menu bar items
- [x] Hide application menus when they overlap with shown menu bar items
- [x] Drag and drop interface to arrange individual menu bar items
- [x] Display hidden menu bar items in a separate bar (e.g. for MacBooks with the notch)
- [x] Search menu bar items
- [x] Menu bar item spacing (BETA)
- [ ] Profiles for menu bar layout
- [ ] Individual spacer items
- [ ] Menu bar item groups
- [ ] Show menu bar items when trigger conditions are met

### Menu bar appearance

- [x] Menu bar tint (solid and gradient)
- [x] Menu bar shadow
- [x] Menu bar border
- [x] Custom menu bar shapes (rounded and/or split)
- [ ] Remove background behind menu bar
- [ ] Rounded screen corners
- [ ] Different settings for light/dark mode

### Hotkeys

- [x] Toggle individual menu bar sections
- [x] Show the search panel
- [x] Enable/disable the Ice Bar
- [x] Show/hide section divider icons
- [x] Toggle application menus
- [ ] Enable/disable auto rehide
- [ ] Temporarily show individual menu bar items

### Other

- [x] Launch at login
- [x] Automatic updates
- [ ] Menu bar widgets

## Why does Ice only support macOS 14 and later?

Ice uses a number of system APIs that are available starting in macOS 14. As such, there are no plans to support earlier versions of macOS.

## Gallery

#### Show hidden menu bar items below the menu bar

The Ice Bar uses a native frosted background that blurs the windows behind it
while keeping menu bar icons sharp. It respects macOS Reduce Transparency,
which replaces the blur with a solid background.

![Ice Bar](https://github.com/user-attachments/assets/f1429589-6186-4e1b-8aef-592219d49b9b)

#### Drag-and-drop interface to arrange menu bar items

![Menu Bar Layout](https://github.com/user-attachments/assets/095442ba-f2d0-4bb4-9632-91e26ef8d45b)

#### Customize the menu bar's appearance

Tint, shadow, border and shape use one shared configuration in both system
appearances. When upgrading from dynamic appearance settings, Ice preserves
the configuration active at the first launch and uses it for subsequent launches.
The separate light/dark editors and preview controls are no longer available.

The **Background blur** slider continuously adjusts a blurred wallpaper crop
behind the system menu bar text and icons (0–100%, mapping to a 0–30 point
radius). Zero restores the original system background; it does not remove the
system's own blur. The wallpaper is sampled every five seconds and after space
or appearance changes, so animated wallpaper is not reproduced frame by frame.
Rounded and split shapes keep the unblurred wallpaper outside the menu shape.

This requires screen recording permission and private macOS compositing support.
Reduce Transparency disables it; missing capture or compositor support restores
the system background. The compositor has been exercised on macOS 15.5; other
macOS versions and multiple displays still need validation. Background estimation
may leave small color differences around text on complex wallpapers or highlighted
menus. Ice does not modify the desktop wallpaper or system appearance preference.

![Menu Bar Appearance](https://github.com/user-attachments/assets/8c22c185-c3d2-49bb-971e-e1fc17df04b3)

#### Menu bar item search

![Menu Bar Item Search](https://github.com/user-attachments/assets/d1a7df3a-4989-4077-a0b1-8e7d5a1ba5b8)

#### Custom menu bar item spacing

![Menu Bar Item Spacing](https://github.com/user-attachments/assets/b196aa7e-184a-4d4c-b040-502f4aae40a6)

## License

Ice is available under the [GPL-3.0 license](LICENSE).
