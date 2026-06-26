#!/bin/bash

set -e

echo "========================================"
echo "🚀 Edu3 Production Setup Starting..."
echo "========================================"

# Update packages
sudo apt-get update

# Install Git
sudo apt-get install -y git curl unzip zip wget xz-utils

# Install Flutter
if [ ! -d "$HOME/flutter" ]; then
    echo "Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
fi

echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/flutter/bin:$PATH"

flutter --version

# Go to project
cd /workspaces/Edu3

# Get packages
flutter pub get

echo ""
echo "✅ Edu3 setup completed successfully."