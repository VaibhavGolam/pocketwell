#!/usr/bin/env python3
"""Patches the folders created by `flutter create` so Pocketwell builds.

Safe to run more than once. It does three things on Android:
  1. adds the notification permissions to AndroidManifest.xml
  2. sets the app name to Pocketwell
  3. turns on core library desugaring (flutter_local_notifications needs it)
and sets the display name on iOS.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "android" / "app"
DESUGAR = "com.android.tools:desugar_jdk_libs:2.1.5"


def patch_manifest() -> None:
    path = APP / "src" / "main" / "AndroidManifest.xml"
    text = path.read_text(encoding="utf-8")

    perms = [
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
    ]
    add = "".join(
        f'    <uses-permission android:name="{p}"/>\n'
        for p in perms
        if p not in text
    )
    if add:
        text = text.replace("<application", add + "    <application", 1)

    text = re.sub(r'android:label="[^"]*"', 'android:label="Pocketwell"', text, count=1)
    path.write_text(text, encoding="utf-8")
    print("patched AndroidManifest.xml")


def patch_gradle() -> None:
    kts = APP / "build.gradle.kts"
    groovy = APP / "build.gradle"

    if kts.exists():
        text = kts.read_text(encoding="utf-8")
        if "isCoreLibraryDesugaringEnabled" not in text:
            text, n = re.subn(
                r"(compileOptions\s*\{)",
                r"\1\n        isCoreLibraryDesugaringEnabled = true",
                text,
                count=1,
            )
            if n == 0:
                sys.exit("could not find compileOptions in build.gradle.kts")
        if "desugar_jdk_libs" not in text:
            text = text.rstrip() + (
                f'\n\ndependencies {{\n    coreLibraryDesugaring("{DESUGAR}")\n}}\n'
            )
        kts.write_text(text, encoding="utf-8")
        print("patched build.gradle.kts")
    elif groovy.exists():
        text = groovy.read_text(encoding="utf-8")
        if "coreLibraryDesugaringEnabled" not in text:
            text, n = re.subn(
                r"(compileOptions\s*\{)",
                r"\1\n        coreLibraryDesugaringEnabled true",
                text,
                count=1,
            )
            if n == 0:
                sys.exit("could not find compileOptions in build.gradle")
        if "desugar_jdk_libs" not in text:
            text = text.rstrip() + (
                f"\n\ndependencies {{\n    coreLibraryDesugaring '{DESUGAR}'\n}}\n"
            )
        groovy.write_text(text, encoding="utf-8")
        print("patched build.gradle")
    else:
        sys.exit("no android/app/build.gradle(.kts) found. Run flutter create first.")


def patch_ios() -> None:
    path = ROOT / "ios" / "Runner" / "Info.plist"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    text = re.sub(
        r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
        r"\1Pocketwell\2",
        text,
    )
    path.write_text(text, encoding="utf-8")
    print("patched Info.plist")


if __name__ == "__main__":
    patch_manifest()
    patch_gradle()
    patch_ios()
