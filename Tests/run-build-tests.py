#!/usr/bin/env python3
"""Validate the real app bundle, including relocation and missing-resource failures."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "build/Ice.app"


def validate(app):
    return subprocess.run([str(app / "Contents/MacOS/Ice"), "--validate-build"],
                          capture_output=True, text=True, timeout=30)


def expect(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    expect(APP.is_dir(), "Build Ice first with ./scripts/build-app.sh")
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(APP)], check=True)
    linked = subprocess.check_output(["/usr/bin/otool", "-L", str(APP / "Contents/MacOS/Ice")], text=True)
    expect("@rpath/Sparkle.framework" in linked, "Sparkle must load from the app's Frameworks directory")
    expect(".build/" not in linked, "The executable links a dependency in the build cache")
    with tempfile.TemporaryDirectory(prefix="ice-build-tests-") as temporary:
        root = Path(temporary)
        moved = root / "Directory with spaces" / "Ice.app"
        shutil.copytree(APP, moved, symlinks=True)
        result = validate(moved)
        expect(result.returncode == 0, result.stdout + result.stderr)
        print(result.stdout.strip())

        # A missing image must fail instead of falling back to files in the checkout.
        resource_bundle = moved / "Contents/Resources/Ice_Ice.bundle"
        image = resource_bundle / "Assets.xcassets/ControlItemImages/IceCube/IceCubeStroke.imageset/IceCubeStroke.png"
        image.unlink()
        result = validate(moved)
        expect(result.returncode != 0 and "Missing image: IceCubeStroke" in result.stderr,
               "Missing-image negative control did not fail for the intended reason")
        resource_bundle.rename(root / "removed-resources.bundle")
        result = validate(moved)
        expect(result.returncode != 0 and "Packaged SwiftPM resources are missing" in result.stderr,
               "Missing-bundle negative control did not fail for the intended reason")

        specification = importlib.util.spec_from_file_location("ice_packager", ROOT / "scripts/package-app.py")
        packager = importlib.util.module_from_spec(specification)
        specification.loader.exec_module(packager)
        sentinel = root / "user-data"
        sentinel.mkdir()
        (sentinel / "keep.txt").write_text("preserve me")
        link = root / "symlink.app"
        link.symlink_to(sentinel, target_is_directory=True)
        for unsafe in [link, sentinel]:
            try:
                packager.ensure_replaceable(unsafe)
            except ValueError:
                pass
            else:
                raise AssertionError(f"Unsafe replacement target accepted: {unsafe}")
        expect((sentinel / "keep.txt").read_text() == "preserve me", "Guard changed user data")
    print("PASS: signature, framework linkage, relocation with spaces, missing-resource failures, safe replacement guards")


if __name__ == "__main__":
    main()
