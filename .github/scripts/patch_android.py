"""Adds Gabay permissions to the Android manifest and sets minSdk to 24.
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
text = re.sub(r'android:label="[^"]*"', 'android:label="Gabay"', text, count=1)
manifest.write_text(text)

# 3) Force older plugins to compile against a newer Android SDK
#    (some plugins still say compileSdk 33, but their libraries need 34+).
KTS_BLOCK = '''// Gabay: compile every Android library plugin against SDK 36
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            val ext = extensions.findByName("android")
            if (ext != null) {
                try {
                    ext.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java).invoke(ext, 36)
                } catch (e: Exception) {
                    ext.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(ext, 36)
                }
            }
        }
    }
}

'''
GROOVY_BLOCK = '''// Gabay: compile every Android library plugin against SDK 36
subprojects {
    afterEvaluate { p ->
        if (p.plugins.hasPlugin("com.android.library")) {
            p.android { compileSdkVersion 36 }
        }
    }
}

'''
for name, block in (("build.gradle.kts", KTS_BLOCK), ("build.gradle", GROOVY_BLOCK)):
    rootGradle = root / "android" / name
    if not rootGradle.exists():
        continue
    g = rootGradle.read_text()
    if "Gabay: compile every" not in g:
        idx = g.find("allprojects")
        g = (g[:idx] + block + g[idx:]) if idx >= 0 else (block + g)
        rootGradle.write_text(g)
        print(f"compileSdk override added to android/{name}")

# 4) minSdk 24 (Kotlin DSL or Groovy)
for name in ("build.gradle.kts", "build.gradle"):
    gradle = root / "android/app" / name
    if not gradle.exists():
        continue
    g = gradle.read_text()
    g = re.sub(r"minSdk\s*=\s*[\w.]+", "minSdk = 24", g)
    g = re.sub(r"minSdkVersion\s+[\w.]+", "minSdkVersion 24", g)
    gradle.write_text(g)
    print(f"minSdk set to 24 in {name}")

# 5) Native light sensor reader for the Auto theme (replaces the outdated plugin)
for act in (root / "android/app/src/main").rglob("MainActivity.kt"):
    act.write_text((root / "android_setup/MainActivity.kt").read_text())
    print(f"MainActivity written: {act}")

# 6) R8 rules: TensorFlow Lite GPU and ML Kit optional language classes are not bundled
rules = root / "android/app/proguard-rules.pro"
extra = """
-dontwarn org.tensorflow.lite.gpu.**
-keep class org.tensorflow.lite.** { *; }
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
"""
old = rules.read_text() if rules.exists() else ""
if "org.tensorflow.lite.gpu" not in old:
    rules.write_text(old + extra)
    print("proguard rules written")
