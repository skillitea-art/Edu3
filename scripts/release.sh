#!/bin/bash
set -e

PROJECT_DIR="/workspaces/Edu3"
cd "$PROJECT_DIR"

echo "========================================"
echo "🚀 VEDO Release Builder"
echo "========================================"

pkill -f gradle || true
pkill -f java || true

JAVA_BIN=$(which java)
export JAVA_HOME=$(dirname $(dirname $(readlink -f "$JAVA_BIN")))
export PATH="$JAVA_HOME/bin:$PATH"

echo "Using Java:"
java -version

export PATH="/home/codespace/flutter/bin:$PATH"

export ANDROID_HOME="/home/vscode/android-sdk"
export ANDROID_SDK_ROOT="/home/vscode/android-sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
VERSION_NAME=$(echo "$VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$VERSION" | cut -d'+' -f2)

echo ""
echo "Version Name : $VERSION_NAME"
echo "Version Code : $VERSION_CODE"

cat > android/local.properties <<EOF
sdk.dir=/home/vscode/android-sdk
flutter.sdk=/home/codespace/flutter
flutter.buildMode=release
flutter.versionName=$VERSION_NAME
flutter.versionCode=$VERSION_CODE
EOF

cat > android/gradle.properties <<EOF
org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.configureondemand=false
org.gradle.caching=false

org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=512m -Dkotlin.daemon.jvm.options=-Xmx512m

android.useAndroidX=true
android.enableJetifier=true
EOF

echo ""
echo "Cleaning..."

rm -rf ~/.gradle
rm -rf build
rm -rf .dart_tool

flutter clean
flutter pub get

unset _JAVA_OPTIONS
unset JAVA_TOOL_OPTIONS

export _JAVA_OPTIONS="-Xmx2048m -Xms512m"
export GRADLE_OPTS="-Dorg.gradle.daemon=false"

echo ""
echo "Building APK..."

flutter build apk 
--release 
--android-skip-build-dependency-validation 
--no-tree-shake-icons

mkdir -p release

APK_NAME="VEDO-v${VERSION_NAME}+${VERSION_CODE}.apk"

cp build/app/outputs/flutter-apk/app-release.apk "release/$APK_NAME"

echo ""
echo "APK Created:"
echo "release/$APK_NAME"
