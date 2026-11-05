<div align="center">
    <img src="Ice/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="Ice" width="200" height="200">
    <h1>Ice</h1>
    <p><a href="README.md">简体中文</a> · <strong>English</strong></p>
    <p>Ice is a menu bar management tool for macOS 14 and later.</p>
    <p>This project is based on <a href="https://github.com/jordanbaird/Ice">jordanbaird/Ice</a> and is developed independently.</p>
    <p>
        <a href="https://github.com/lihangfu/Ice/releases/latest"><img src="https://img.shields.io/badge/download-latest-brightgreen?style=flat-square" alt="Download"></a>
        <img src="https://img.shields.io/badge/platform-macOS-blue?style=flat-square" alt="Platform">
        <img src="https://img.shields.io/badge/requirements-macOS%2014%2B-fa4e49?style=flat-square" alt="Requirements">
        <a href="LICENSE"><img src="https://img.shields.io/github/license/lihangfu/Ice?style=flat-square" alt="License"></a>
    </p>
</div>

## Install

Download the "Ice.zip" file from the [latest release](https://github.com/lihangfu/Ice/releases/latest) and move the unzipped app into your `Applications` folder.

## Features

Settings show contextual explanations behind the circled question mark next to
each relevant setting's name. Hover to read the explanation, or activate the help
button with a click or keyboard to open it in a popover. Operational warnings and
status messages remain visible in the settings page.

### Menu bar item management

- Hide menu bar items
- "Always-hidden" menu bar section
- Show hidden menu bar items when hovering over the menu bar
- Show hidden menu bar items when an empty area in the menu bar is clicked
- Show hidden menu bar items by scrolling or swiping in the menu bar
- Automatically rehide menu bar items
- Hide application menus when they overlap with shown menu bar items
- Drag and drop interface to arrange individual menu bar items
- Display hidden menu bar items in a separate bar (e.g. for MacBooks with the notch)
- Search menu bar items
- Menu bar item spacing (BETA)

### Menu bar appearance

- Menu bar tint (solid and gradient)
- Menu bar shadow
- Menu bar border
- Custom menu bar shapes (rounded and/or split)

### Hotkeys

- Toggle individual menu bar sections
- Show the search panel
- Enable/disable the Ice Bar
- Show/hide section divider icons
- Toggle application menus

### Other

- Launch at login
- Automatic updates

## Why does Ice only support macOS 14 and later?

Ice uses system APIs that are available starting in macOS 14.

## Appearance

### Ice Bar and menu bar layout

The Ice Bar uses a native frosted background that blurs the windows behind it
while keeping menu bar icons sharp. It respects macOS Reduce Transparency,
which replaces the blur with a solid background. Monochrome icons with transparent
backgrounds adapt to the system light/dark appearance. Colored or ambiguous
captures keep their original colors, including mixed icons with status badges.
This adaptation applies to Ice Bar and the visible, hidden, and always-hidden
sections in settings. Drag previews use the same themed colors. Search results
keep the originals.

### Menu bar customization

Tint, shadow, border and shape share one configuration across light and dark
appearances. Menu bar background blur cannot be customized.

[Common issues](FREQUENT_ISSUES.md) · [Report a problem](https://github.com/lihangfu/Ice/issues) · [Developer guide](docs/development.en.md)

## License

Ice is available under the [GPL-3.0 license](LICENSE).
