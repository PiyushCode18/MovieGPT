#!/bin/bash
set -e

echo "======================================"
echo "Installing Flutter..."
echo "======================================"

git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"

export PATH="$HOME/flutter/bin:$PATH"

echo "======================================"
echo "Flutter version"
echo "======================================"

flutter --version

echo "======================================"
echo "Enabling Flutter Web"
echo "======================================"

flutter config --enable-web

echo "======================================"
echo "Getting dependencies"
echo "======================================"

flutter pub get

echo "======================================"
echo "Building MovieGPT"
echo "======================================"

flutter build web --release

echo "======================================"
echo "BUILD SUCCESSFUL"
echo "======================================"
