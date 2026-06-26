#!/bin/bash

set -e

PROJECT_DIR="/workspaces/Edu3"

cd "$PROJECT_DIR"

echo "========================================"
echo "🚀 Edu3 Release Builder"
echo "========================================"

# Java
# Java
if [ -d "/usr/local/sdkman/candidates/java/21.0.10-ms" ]; then
    export JAVA_HOME="/usr/local/sdkman/candidates/java/21.0.10-ms"
else
    export JAVA_HOME="/usr/local/sdkman/candidates/java/current"
fi

export PATH="$JAVA_HOME/bin:$PATH"

hash -r

echo "Using Java:"
java -version

# Flutter
if [ -d "$HOME/flutter" ]; then
    export PATH="$HOME/flutter/bin:$PATH"
fi

# Android SDK
if [ -d "$HOME/android-sdk" ]; then
    export ANDROID_HOME="$HOME/android-sdk"
    export ANDROID_SDK_ROOT="$HOME/android-sdk"
    export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
fi

# ---------- Read Version ----------
VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')

VERSION_NAME=$(echo "$VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$VERSION" | cut -d'+' -f2)

echo ""
echo "Version Name : $VERSION_NAME"
echo "Version Code : $VERSION_CODE"

# ---------- Update local.properties ----------
cat > android/local.properties <<EOF
sdk.dir=$HOME/android-sdk
flutter.sdk=$HOME/flutter
flutter.buildMode=release
flutter.versionName=$VERSION_NAME
flutter.versionCode=$VERSION_CODE
EOF

echo ""
echo "✔ local.properties updated"

flutter pub get

echo ""
echo "Building Release APK..."

cd android

./gradlew --no-daemon \
-Dorg.gradle.jvmargs="-Xmx2g -XX:MaxMetaspaceSize=512m" \
assembleRelease

cd ..

mkdir -p release

APK_NAME="Vedo-v${VERSION_NAME}+${VERSION_CODE}.apk"

cp build/app/outputs/flutter-apk/app-release.apk "release/$APK_NAME"

echo ""
echo "========================================"
echo "✅ BUILD SUCCESSFUL"
echo "========================================"
echo ""
echo "APK:"
echo "release/$APK_NAME"