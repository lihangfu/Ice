#!/usr/bin/env python3
"""Package the SwiftPM executable using the existing Xcode metadata and assets."""
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def build_settings(configuration):
    project = json.loads(subprocess.check_output([
        "/usr/bin/plutil", "-convert", "json", "-o", "-", str(ROOT / "Ice.xcodeproj/project.pbxproj")
    ]))
    objects = project["objects"]
    target = next(value for value in objects.values()
                  if value.get("isa") == "PBXNativeTarget" and value.get("name") == "Ice")
    settings = {}
    for owner in [objects[project["rootObject"]], target]:
        configurations = objects[owner["buildConfigurationList"]]["buildConfigurations"]
        selected = next(objects[key] for key in configurations if objects[key]["name"].lower() == configuration)
        settings.update(selected["buildSettings"])
    return settings


def ensure_replaceable(destination):
    if destination.is_symlink():
        raise ValueError(f"Refusing to replace a symbolic link: {destination}")
    executable = str(destination / "Contents/MacOS/Ice")
    processes = subprocess.check_output(["/bin/ps", "-axo", "comm="], text=True).splitlines()
    if executable in (line.strip() for line in processes):
        raise ValueError("Quit the running build/Ice.app before rebuilding it.")
    if destination.exists() and not (destination / "Contents/Info.plist").is_file():
        raise ValueError(f"Refusing to replace a directory that is not an app bundle: {destination}")


def package(binary_directory, configuration):
    binary_directory = binary_directory.resolve(strict=True)
    settings = build_settings(configuration)
    output_directory = ROOT / "build"
    if output_directory.is_symlink():
        raise ValueError("The build output directory must not be a symbolic link.")
    output_directory.mkdir(exist_ok=True)
    destination = output_directory / "Ice.app"
    ensure_replaceable(destination)

    with tempfile.TemporaryDirectory(prefix="ice-package-", dir=output_directory) as temporary:
        stage = Path(temporary) / "Ice.app"
        contents = stage / "Contents"
        resources = contents / "Resources"
        frameworks = contents / "Frameworks"
        (contents / "MacOS").mkdir(parents=True)
        resources.mkdir()
        frameworks.mkdir()
        shutil.copy2(binary_directory / "Ice", contents / "MacOS/Ice")
        shutil.copytree(binary_directory / "Sparkle.framework", frameworks / "Sparkle.framework", symlinks=True)
        shutil.copytree(binary_directory / "Ice_Ice.bundle", resources / "Ice_Ice.bundle")
        # SwiftUI and AppLanguage use Bundle.main for strings and acknowledgements.
        for item in (ROOT / "Ice/Resources").iterdir():
            if item.suffix == ".lproj":
                shutil.copytree(item, resources / item.name)
            elif item.suffix == ".pdf":
                shutil.copy2(item, resources / item.name)

        icon_source = ROOT / "Ice/Assets.xcassets/AppIcon.appiconset"
        icon_set = Path(temporary) / "AppIcon.iconset"
        icon_set.mkdir()
        for entry in json.loads((icon_source / "Contents.json").read_text())["images"]:
            filename = entry.get("filename")
            if filename:
                scale = "@2x" if entry["scale"] == "2x" else ""
                shutil.copy2(icon_source / filename, icon_set / f"icon_{entry['size']}{scale}.png")
        run("/usr/bin/iconutil", "--convert", "icns", "--output", resources / "AppIcon.icns", icon_set)

        with (ROOT / "Ice/Info.plist").open("rb") as source:
            info = plistlib.load(source)
        info.pop("SUPublicEDKey", None)
        info.update({
            "CFBundleExecutable": "Ice",
            "CFBundleName": "Ice",
            "CFBundleDisplayName": "Ice",
            "CFBundleIdentifier": settings["PRODUCT_BUNDLE_IDENTIFIER"],
            "CFBundlePackageType": "APPL",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleShortVersionString": str(settings["MARKETING_VERSION"]),
            "CFBundleVersion": str(settings["CURRENT_PROJECT_VERSION"]),
            "CFBundleDevelopmentRegion": "en",
            "CFBundleLocalizations": ["en", "zh-Hans"],
            "CFBundleIconFile": "AppIcon",
            "LSMinimumSystemVersion": str(settings["MACOSX_DEPLOYMENT_TARGET"]),
            "LSApplicationCategoryType": settings["INFOPLIST_KEY_LSApplicationCategoryType"],
            "LSUIElement": True,
            "NSHighResolutionCapable": True,
            "NSHumanReadableCopyright": settings["INFOPLIST_KEY_NSHumanReadableCopyright"],
            "IceLocalBuild": True,
            "SUEnableAutomaticChecks": False,
            "SUAllowsAutomaticUpdates": False,
        })
        with (contents / "Info.plist").open("wb") as output:
            plistlib.dump(info, output)
        (contents / "PkgInfo").write_bytes(b"APPL????")
        # Ad-hoc signing is for local use; distributed builds retain the Xcode release workflow.
        run("/usr/bin/codesign", "--force", "--deep", "--sign", "-", "--entitlements", ROOT / "Ice/Ice.entitlements", stage)
        run("/usr/bin/codesign", "--verify", "--deep", "--strict", stage)
        ensure_replaceable(destination)
        if destination.exists():
            shutil.rmtree(destination)
        os.rename(stage, destination)
    print(f"Built {destination}")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3 or sys.argv[2] not in ("debug", "release"):
            raise ValueError("Usage: package-app.py <SwiftPM bin path> <debug|release>")
        package(Path(sys.argv[1]), sys.argv[2])
    except (OSError, ValueError, KeyError, StopIteration, subprocess.CalledProcessError) as error:
        print(f"Packaging failed: {error}", file=sys.stderr)
        sys.exit(1)
