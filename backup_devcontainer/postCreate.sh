#!/bin/bash

set -e

echo "===================================="
echo "Setting up Edu3 Development Environment"
echo "===================================="

# Flutter
if [ ! -d "$HOME/flutter" ]; then
  echo "Installing Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
fi

echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
export PATH="$PATH:$HOME/flutter/bin"

# Java 21
export JAVA_HOME=/usr/local/sdkman/candidates/java/21.0.10-ms
export PATH="$JAVA_HOME/bin:$PATH"

# Flutter packages
cd /workspaces/Edu3
flutter pub get

echo ""
echo "✅ Edu3 setup completed successfully."