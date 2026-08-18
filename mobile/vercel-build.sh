#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.44.2"
FLUTTER_DIR="flutter"

# Remove leftover SDK dir or accidental placeholder file that blocks git clone.
if [ -e "$FLUTTER_DIR" ]; then
  rm -rf "$FLUTTER_DIR"
fi

echo "Cloning Flutter SDK ${FLUTTER_VERSION}..."
git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_DIR"
export PATH="$PATH:$(pwd)/$FLUTTER_DIR/bin"

flutter config --enable-web --no-analytics
flutter precache --web

echo "Getting dependencies..."
flutter pub get

echo "Building web..."
flutter build web --release \
  --base-href / \
  --dart-define=API_BASE_URL=https://runna-backend.onrender.com/api
