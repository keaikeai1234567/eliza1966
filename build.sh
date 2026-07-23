#!/bin/bash
set -e

PROJECT=/data/user/work/eliza1966
BT=/opt/android-sdk/build-tools/34.0.0
PLATFORM=/opt/android-sdk/platforms/android-34/android.jar
ASSETS=$PROJECT/app/src/main/assets
RES=$PROJECT/app/src/main/res
JAVA=$PROJECT/app/src/main/java
BUILD=$PROJECT/build
MANIFEST=$PROJECT/app/src/main/AndroidManifest.xml
KEYSTORE=$PROJECT/debug.keystore

echo "=== 清理 ==="
rm -f $BUILD/unsigned.apk $BUILD/aligned.apk $BUILD/eliza1966.apk $BUILD/unsigned.zip
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

echo "=== 3. aapt2 编译资源 ==="
$BT/aapt2 compile --dir $RES -o $BUILD/compiled_res.zip 2>&1

echo "=== 4. aapt2 链接 ==="
$BT/aapt2 link \
  -o $BUILD/unsigned.apk \
  -I $PLATFORM \
  --manifest $MANIFEST \
  --min-sdk-version 21 \
  --target-sdk-version 30 \
  --version-code 13 \
  --version-name "5.2" \
  -A $ASSETS \
  $BUILD/compiled_res.zip 2>&1

echo "=== 5. 添加 classes.dex ==="
cd $BUILD/lib
$BT/aapt add $BUILD/unsigned.apk classes.dex 2>&1
cd $PROJECT

echo "=== 6. Zipalign ==="
$BT/zipalign -f -p 4 $BUILD/unsigned.apk $BUILD/aligned.apk

echo "=== 7. 签名 (jarsigner v1 + apksigner v2) ==="
# 1. jarsigner v1 签名
jarsigner -keystore $KEYSTORE \
  -storepass android \
  -keypass android \
  -sigalg SHA256withRSA \
  -digestalg SHA-256 \
  $BUILD/aligned.apk androiddebugkey 2>&1

# 2. 重新 zipalign（jarsigner 破坏对齐）
$BT/zipalign -f -p 4 $BUILD/aligned.apk $BUILD/aligned2.apk

# 3. apksigner 添加 v2/v3（保留 v1，不重新生成 v1）
$BT/apksigner sign \
  --ks $KEYSTORE \
  --ks-pass pass:android \
  --ks-key-alias androiddebugkey \
  --key-pass pass:android \
  --v1-signing-enabled true \
  --v2-signing-enabled true \
  --v3-signing-enabled true \
  --out $BUILD/eliza1966.apk \
  $BUILD/aligned2.apk 2>&1

echo "=== 8. 验证 ==="
$BT/apksigner verify --verbose $BUILD/eliza1966.apk 2>&1
echo ""
$BT/aapt dump badging $BUILD/eliza1966.apk 2>&1 | head -10
echo ""
ls -lh $BUILD/eliza1966.apk
echo "=== Done ==="
