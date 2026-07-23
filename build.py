#!/usr/bin/env python3
"""用 Python zipfile 重建 APK，确保 ZIP 结构规范（无 data descriptor）"""
import zipfile
import os
import sys
import shutil
import subprocess

PROJECT = "/data/user/work/eliza-android"
BT = "/opt/android-sdk/build-tools/34.0.0"
PLATFORM = "/opt/android-sdk/platforms/android-34/android.jar"
BUILD = f"{PROJECT}/build"
ASSETS = f"{PROJECT}/app/src/main/assets"
RES = f"{PROJECT}/app/src/main/res"
JAVA = f"{PROJECT}/app/src/main/java"
MANIFEST = f"{PROJECT}/app/src/main/AndroidManifest.xml"
KEYSTORE = f"{PROJECT}/debug.keystore"

# 清理
for f in ["linked-res.apk", "unsigned.apk", "aligned.apk", "eliza1966.apk", "resources.zip"]:
    p = f"{BUILD}/{f}"
    if os.path.exists(p):
        os.remove(p)
for d in ["obj", "lib"]:
    p = f"{BUILD}/{d}"
    if os.path.exists(p):
        shutil.rmtree(p)
    os.makedirs(p)

print("=== 1. Compile resources ===")
subprocess.run([f"{BT}/aapt2", "compile", "--dir", RES, "-o", f"{BUILD}/resources.zip"], check=True)

print("=== 2. Link resources ===")
subprocess.run([
    f"{BT}/aapt2", "link",
    "-o", f"{BUILD}/linked-res.apk",
    "-I", PLATFORM,
    "--manifest", MANIFEST,
    "--min-sdk-version", "24",
    "--target-sdk-version", "34",
    "--version-code", "6",
    "--version-name", "3.3",
    "-A", ASSETS,
    f"{BUILD}/resources.zip"
], check=True)

print("=== 3. Compile Java ===")
subprocess.run([
    "javac", "-source", "17", "-target", "17",
    "-classpath", PLATFORM,
    "-d", f"{BUILD}/obj",
    f"{JAVA}/com/eliza/doctor/MainActivity.java"
], check=True)

print("=== 4. DEX ===")
subprocess.run([
    f"{BT}/d8", "--release", "--min-api", "24",
    "--output", f"{BUILD}/lib",
    f"{BUILD}/obj/com/eliza/doctor/MainActivity.class"
], check=True)

print("=== 5. 用 Python 重建 APK (规范ZIP结构) ===")
# 读取 aapt2 生成的 APK 中的所有文件
entries = []
with zipfile.ZipFile(f"{BUILD}/linked-res.apk", "r") as zin:
    for info in zin.infolist():
        entries.append((info.filename, zin.read(info.filename)))

# 添加 classes.dex
with open(f"{BUILD}/lib/classes.dex", "rb") as f:
    entries.append(("classes.dex", f.read()))

# 重建 ZIP：不使用 data descriptor，确保 ZIP64 不会有问题
with zipfile.ZipFile(f"{BUILD}/unsigned.apk", "w", zipfile.ZIP_DEFLATED) as zout:
    for name, data in entries:
        # classes.dex 不压缩（store），其它默认压缩
        if name == "classes.dex":
            zout.writestr(name, data, zipfile.ZIP_STORED)
        else:
            zout.writestr(name, data, zipfile.ZIP_DEFLATED)

print(f"   APK 包含 {len(entries)} 个文件")

print("=== 6. Zipalign ===")
subprocess.run([f"{BT}/zipalign", "-f", "-p", "4", f"{BUILD}/unsigned.apk", f"{BUILD}/aligned.apk"], check=True)

print("=== 7. Sign (v1+v2+v3) ===")
result = subprocess.run([
    f"{BT}/apksigner", "sign",
    "--ks", KEYSTORE,
    "--ks-pass", "pass:android",
    "--ks-key-alias", "androiddebugkey",
    "--key-pass", "pass:android",
    "--v1-signing-enabled", "true",
    "--v2-signing-enabled", "true",
    "--v3-signing-enabled", "true",
    "--out", f"{BUILD}/eliza1966.apk",
    f"{BUILD}/aligned.apk"
], capture_output=True, text=True)
if result.stderr:
    print("STDERR:", result.stderr)
if result.stdout:
    print("STDOUT:", result.stdout)

print("=== 8. 验证 ===")
result = subprocess.run([f"{BT}/apksigner", "verify", "--verbose", f"{BUILD}/eliza1966.apk"], capture_output=True, text=True)
print(result.stdout)

print("=== 9. jarsigner 验证 ===")
result = subprocess.run(["jarsigner", "-verify", f"{BUILD}/eliza1966.apk"], capture_output=True, text=True)
print(result.stdout)
if "inconsistencies" in (result.stderr + result.stdout):
    print("WARNING: ZIP 结构仍有不一致!")
else:
    print("ZIP 结构一致，无问题")

print("=== 10. Badging ===")
result = subprocess.run([f"{BT}/aapt2", "dump", "badging", f"{BUILD}/eliza1966.apk"], capture_output=True, text=True)
for line in result.stdout.split("\n")[:8]:
    print(line)

print("=== 11. 完整性 ===")
result = subprocess.run(["unzip", "-t", f"{BUILD}/eliza1966.apk"], capture_output=True, text=True)
print(result.stdout.split("\n")[-3] if result.stdout else "ERROR")

print("=== 12. SHA256 ===")
import hashlib
with open(f"{BUILD}/eliza1966.apk", "rb") as f:
    sha = hashlib.sha256(f.read()).hexdigest()
print(sha)

size = os.path.getsize(f"{BUILD}/eliza1966.apk")
print(f"\nAPK 大小: {size / 1024 / 1024:.1f} MB")
print("=== Done ===")
