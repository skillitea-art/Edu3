#!/bin/bash

set -e

echo "========================================"
echo "🚀 Edu3 Automatic Setup"
echo "========================================"

PROJECT_DIR="/workspaces/Edu3"

#############################################
# JAVA
#############################################

echo ""
echo "Checking Java..."

if [ -d "/usr/local/sdkman/candidates/java/21.0.10-ms" ]; then
    export JAVA_HOME="/usr/local/sdkman/candidates/java/21.0.10-ms"

elif [ -d "/usr/local/sdkman/candidates/java/current" ]; then
    export JAVA_HOME="/usr/local/sdkman/candidates/java/current"

else
    echo "❌ Java not found"
    exit 1
fi

export PATH="$JAVA_HOME/bin:$PATH"

hash -r

java -version

#############################################
# FLUTTER
#############################################

echo ""
echo "Checking Flutter..."

if [ ! -d "$HOME/flutter" ]; then

    echo "Flutter not found."

    git clone https://github.com/flutter/flutter.git \
    -b stable \
    --depth 1 \
    $HOME/flutter

fi

export PATH="$HOME/flutter/bin:$PATH"

flutter --version
#############################################
# ANDROID SDK
#############################################

echo ""
echo "Checking Android SDK..."

export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then

    echo "Installing Android SDK..."

    mkdir -p "$ANDROID_HOME"
    cd "$ANDROID_HOME"

    wget -q https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip

    unzip -q commandlinetools-linux-13114758_latest.zip

    mkdir -p cmdline-tools

    mv cmdline-tools latest-temp || true

    mkdir -p cmdline-tools

    mv latest-temp cmdline-tools/latest || true

    rm -f commandlinetools-linux-13114758_latest.zip

fi

yes | sdkmanager --licenses >/dev/null

sdkmanager \
"platform-tools" \
"platforms;android-35" \
"build-tools;35.0.0"

echo "Android SDK Ready"

#############################################
# PROJECT SETUP
#############################################

echo ""
echo "Configuring Project..."

cd "$PROJECT_DIR"

cat > android/local.properties <<EOF
sdk.dir=$HOME/android-sdk
flutter.sdk=$HOME/flutter
flutter.buildMode=release
EOF

flutter doctor

flutter pub get

echo ""
echo "========================================"
echo "✅ Edu3 Setup Completed Successfully"
echo "========================================"
echo ""
echo "Now you can build anytime using:"
echo ""
echo "bash scripts/release.sh"
echo ""