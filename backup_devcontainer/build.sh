#!/bin/bash

set -e

export JAVA_HOME=/usr/local/sdkman/candidates/java/current
export PATH="$JAVA_HOME/bin:$PATH"

echo "Java Version:"
java -version"

cd /workspaces/Edu3/android

echo "=================================="
echo "Building Release APK..."
echo "=================================="

./gradlew --no-daemon \
-Dorg.gradle.jvmargs="-Xmx2g -XX:MaxMetaspaceSize=512m" \
assembleRelease

echo ""
echo "✅ APK Build Successful"
echo ""
echo "APK Location:"
echo "/workspaces/Edu3/build/app/outputs/flutter-apk/app-release.apk"