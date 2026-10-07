#!/usr/bin/env python3
"""Patches the folders created by `flutter create` so Pocketwell builds.

Safe to run more than once. On Android it:
  1. adds the permissions (notifications, boot, fingerprint)
  2. sets the app name to Pocketwell
  3. turns on core library desugaring (flutter_local_notifications needs it)
  4. adds the AppCompat library (the launch themes below use it)
  5. makes every plugin compile against Android SDK 36 (root build file)
  6. makes MainActivity a FragmentActivity and gives the launch themes an
     AppCompat parent (the fingerprint prompt from local_auth needs both)
On iOS it sets the display name and adds the Face ID message.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "android" / "app"
MAIN = APP / "src" / "main"
DESUGAR = "com.android.tools:desugar_jdk_libs:2.1.5"
APPCOMPAT = "androidx.appcompat:appcompat:1.7.0"


def patch_manifest() -> None:
    path = MAIN / "AndroidManifest.xml"
    text = path.read_text(encoding="utf-8")

    perms = [
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.USE_BIOMETRIC",
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
        if "androidx.appcompat:appcompat" not in text:
            text = text.rstrip() + (
                f'\n\ndependencies {{\n    implementation("{APPCOMPAT}")\n}}\n'
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
        if "androidx.appcompat:appcompat" not in text:
            text = text.rstrip() + (
                f"\n\ndependencies {{\n    implementation '{APPCOMPAT}'\n}}\n"
            )
        groovy.write_text(text, encoding="utf-8")
        print("patched build.gradle")
    else:
        sys.exit("no android/app/build.gradle(.kts) found. Run flutter create first.")


ROOT_MARK = "pocketwell: compile every plugin against a recent Android SDK"

KTS_BLOCK = f"""

// {ROOT_MARK}
subprojects {{
    if (name != "app" && !state.executed) {{
        afterEvaluate {{
            extensions.findByName("android")?.let {{ ext ->
                try {{
                    ext.withGroovyBuilder {{ "compileSdkVersion"(36) }}
                }} catch (e: Exception) {{
                    ext.withGroovyBuilder {{ "setCompileSdk"(36) }}
                }}
            }}
        }}
    }}
}}
"""

GROOVY_BLOCK = f"""

// {ROOT_MARK}
subprojects {{ p ->
    if (p.name != 'app' && !p.state.executed) {{
        p.afterEvaluate {{
            if (p.hasProperty('android')) {{
                p.android.compileSdkVersion 36
            }}
        }}
    }}
}}
"""


def patch_root_gradle() -> None:
    """Some plugins (file_picker, local_auth, share_plus) are still compiled
    against an older Android SDK than the Flutter libraries they depend on
    now require, and the build stops with 'requires ... version 36 or later'.
    This makes every plugin compile against SDK 36. The app itself is left alone."""
    kts = ROOT / "android" / "build.gradle.kts"
    groovy = ROOT / "android" / "build.gradle"
    for path, block in ((kts, KTS_BLOCK), (groovy, GROOVY_BLOCK)):
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        if ROOT_MARK not in text:
            path.write_text(text.rstrip() + "\n" + block, encoding="utf-8")
            print(f"patched {path.name}")
        return
    print("warning: android/build.gradle(.kts) not found, plugin SDK fix skipped")


def patch_main_activity() -> None:
    """local_auth needs a FragmentActivity. Without it the fingerprint prompt
    fails (the app falls back to the PIN pad, so nothing crashes)."""
    found = False
    for path in list(MAIN.rglob("MainActivity.kt")) + list(MAIN.rglob("MainActivity.java")):
        found = True
        text = path.read_text(encoding="utf-8")
        if "FlutterFragmentActivity" in text:
            continue
        new = re.sub(r"\bFlutterActivity\b", "FlutterFragmentActivity", text)
        if new != text:
            path.write_text(new, encoding="utf-8")
            print(f"patched {path.name}")
    if not found:
        print("warning: MainActivity not found, fingerprint unlock may not work")


def patch_styles() -> None:
    """local_auth wants an AppCompat theme. Light themes get the light parent,
    night themes the dark one. Only the parent changes, not the window colours."""
    pattern = re.compile(r'(<style\s+name="(?:LaunchTheme|NormalTheme)"\s+parent=")([^"]*)(")')
    for path in sorted((MAIN / "res").glob("values*/styles.xml")):
        night = "night" in path.parent.name
        parent = "Theme.AppCompat.NoActionBar" if night else "Theme.AppCompat.Light.NoActionBar"

        def repl(m: "re.Match[str]") -> str:
            if "Theme.AppCompat" in m.group(2):
                return m.group(0)
            return m.group(1) + parent + m.group(3)

        text = path.read_text(encoding="utf-8")
        new = pattern.sub(repl, text)
        if new != text:
            path.write_text(new, encoding="utf-8")
            print(f"patched {path.parent.name}/styles.xml")


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
    if "NSFaceIDUsageDescription" not in text:
        entry = (
            "\t<key>NSFaceIDUsageDescription</key>\n"
            "\t<string>Pocketwell uses Face ID to unlock the app.</string>\n"
        )
        end = text.rfind("</dict>")
        if end != -1:
            text = text[:end] + entry + text[end:]
    path.write_text(text, encoding="utf-8")
    print("patched Info.plist")


if __name__ == "__main__":
    patch_manifest()
    patch_gradle()
    patch_root_gradle()
    patch_main_activity()
    patch_styles()
    patch_ios()
