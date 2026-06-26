#!/bin/bash

set -e

echo "========================================"
echo "Edu3 Release Build"
echo "========================================"

# Java
if [ -z "$JAVA_HOME" ]; then
  export JAVA_HOME=/usr/local/sdkman/candidates/java/current
fi

export PATH="$JAVA_HOME/bin:$PATH"

# Flutter
if [ -d "$HOME/flutter" ]; then
    export PATH="$HOME/flutter/bin:$PATH"
fi

cd /workspaces/Edu3

echo ""
echo "Flutter Version"
flutter --version

echo ""
echo "Getting Packages..."
flutter pub get

echo ""
echo "Building APK..."
cd android

./gradlew --no-daemon \
-Dorg.gradle.jvmargs="-Xmx2g -XX:MaxMetaspaceSize=512m" \
assembleRelease

echo ""
echo "========================================"
echo "✅ BUILD SUCCESSFUL"
echo "========================================"

echo ""
echo "APK Location:"
echo "/workspaces/Edu3/build/app/outputs/flutter-apk/app-release.apk"