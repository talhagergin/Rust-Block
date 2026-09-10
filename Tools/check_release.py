#!/usr/bin/env python3
"""Validate a local iOS archive. Passing is not App Store validation/approval."""
import argparse
import plistlib
import struct
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("archive", type=Path)
args = parser.parse_args()
app = args.archive / "Products" / "Applications" / "Rust Block.app"
with (app / "Info.plist").open("rb") as source:
    info = plistlib.load(source)
assert info["CFBundleIdentifier"] == "talhagergin.Rust-Block"
assert info["CFBundleDisplayName"] == "Paslanan Bloklar"
assert info["MinimumOSVersion"] == "18.0"
assert info["UIDeviceFamily"] == [1, 2]
assert not info["UIApplicationSceneManifest"]["UIApplicationSupportsMultipleScenes"]
assert info["UISupportedInterfaceOrientations~iphone"] == ["UIInterfaceOrientationPortrait"]
assert not info["ITSAppUsesNonExemptEncryption"]
with (app / "PrivacyInfo.xcprivacy").open("rb") as source:
    privacy = plistlib.load(source)
assert not privacy["NSPrivacyTracking"] and not privacy["NSPrivacyCollectedDataTypes"]
assert any(item["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults" and
           "CA92.1" in item["NSPrivacyAccessedAPITypeReasons"] for item in privacy["NSPrivacyAccessedAPITypes"])
assert len(list(app.glob("*.wav"))) == 11, "Missing audio resources"
binary_strings = subprocess.check_output(["strings", str(app / "Rust Block")], text=True)
assert all(flag not in binary_strings for flag in ["--ui-test-reset", "--line-test", "--rescue-test"])
icon = Path(__file__).resolve().parents[1] / "Rust Block/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
with icon.open("rb") as source:
    header = source.read(26)
assert struct.unpack(">II", header[16:24]) == (1024, 1024)
assert header[25] == 2, "App icon must be RGB without alpha"
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
signature = subprocess.run(["codesign", "-dv", "--verbose=2", str(app)], capture_output=True, text=True, check=True).stderr
identity = next((line for line in signature.splitlines() if line.startswith("Authority=")), "Unsigned/ad-hoc")
print(f"Local archive checks passed: metadata, privacy, icon, 11 audio files, no debug reset flags, signature.\n{identity}")
print("This does not perform App Store Connect validation, distribution export, or TestFlight testing.")
