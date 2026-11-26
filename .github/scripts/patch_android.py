"""Adds Holos permissions to the Android manifest and sets minSdk to 24.
Safe to run more than once."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[2]

# 1) Manifest permissions
manifest = root / "android/app/src/main/AndroidManifest.xml"
perms = (root / "android_setup/AndroidManifest_permissions.xml").read_text()
perms = re.sub(r"<!--.*?-->", "", perms, flags=re.S).strip()
text = manifest.read_text()
if "android.permission.CAMERA" not in text:
    text = text.replace("<application", perms + "\n\n    <application", 1)
    manifest.write_text(text)
    print("Manifest permissions added")

# 2) App label
text = manifest.read_text()
text = re.sub(r'android:label="[^"]*"', 'android:label="Holos"', text, count=1)
manifest.write_text(text)

# 3) minSdk 24 (Kotlin DSL or Groovy)
for name in ("build.gradle.kts", "build.gradle"):
    gradle = root / "android/app" / name
    if not gradle.exists():
        continue
    g = gradle.read_text()
    g = re.sub(r"minSdk\s*=\s*[\w.]+", "minSdk = 24", g)
    g = re.sub(r"minSdkVersion\s+[\w.]+", "minSdkVersion 24", g)
    gradle.write_text(g)
    print(f"minSdk set to 24 in {name}")
