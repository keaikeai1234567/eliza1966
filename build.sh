#!/bin/bash
set -e

PROJECT=/data/user/work/eliza-android
BT=/opt/android-sdk/build-tools/34.0.0
PLATFORM=/opt/android-sdk/platforms/android-34/android.jar
ASSETS=$PROJECT/app/src/main/assets
RES=$PROJECT/app/src/main/res
JAVA=$PROJECT/app/src/main/java
BUILD=$PROJECT/build
MANIFEST=$PROJECT/app/src/main/AndroidManifest.xml
KEYSTORE=$PROJECT/debug.keystore

echo "=== 清理 ==="
rm -f $BUILD/unsigned.apk $BUILD/aligned.apk $BUILD/eliza1966.apk
rm -rf $BUILD/obj $BUILD/lib
mkdir -p $BUILD/obj $BUILD/lib

echo "=== 1. Compile Java ==="
javac -source 17 -target 17 \
  -classpath $PLATFORM \
  -d $BUILD/obj \
  $JAVA/com/eliza/doctor/MainActivity.java 2>&1

echo "=== 2. DEX ==="
CLASSFILES=$(find $BUILD/obj -name "*.class" | tr '\n' ' ')
$BT/d8 --release --min-api 24 --output $BUILD/lib $CLASSFILES

echo "=== 3. aapt 打包 ==="
$BT/aapt package \
  -f \
  -M $MANIFEST \
  -S $RES \
  -A $ASSETS \
  -I $PLATFORM \
  -F $BUILD/unsigned.apk \
  --min-sdk-version 24 \
  --target-sdk-version 34 \
  --version-code 11 \
  --version-name "5.0" \
  2>&1

echo "=== 4. 添加 classes.dex ==="
cd $BUILD/lib
$BT/aapt add $BUILD/unsigned.apk classes.dex 2>&1
cd $PROJECT

echo "=== 5. Zipalign ==="
$BT/zipalign -f -p 4 $BUILD/unsigned.apk $BUILD/aligned.apk

echo "=== 6. 签名 ==="
$BT/apksigner sign \
  --ks $KEYSTORE \
  --ks-pass pass:android \
  --ks-key-alias androiddebugkey \
  --key-pass pass:android \
  --v1-signing-enabled true \
  --v2-signing-enabled true \
  --v3-signing-enabled true \
  --out $BUILD/eliza1966.apk \
  $BUILD/aligned.apk 2>&1

echo "=== 7. 验证 ==="
$BT/apksigner verify --verbose $BUILD/eliza1966.apk 2>&1
echo ""
$BT/aapt dump badging $BUILD/eliza1966.apk 2>&1 | head -8
echo ""
ls -lh $BUILD/eliza1966.apk
echo "=== Done ==="
