#!/bin/bash

# Exit on error
set -e

echo "----------------------------------------------------------------"
echo "Starting Custom Flutter Build Script"
echo "----------------------------------------------------------------"

# 1. Install Flutter (since it's not in the default Vercel image)
if [ -d "flutter" ]; then
    echo "Flutter directory already exists. Skipping clone."
else
    echo "Cloning Flutter stable..."
    git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter Version:"
flutter --version

# 2. Decode the ignored firebase_options.dart file
# We expect a base64 string in the Environment Variable: FIREBASE_OPTIONS_BASE64
echo "Checking for FIREBASE_OPTIONS_BASE64..."
if [ -n "$FIREBASE_OPTIONS_BASE64" ]; then
    echo "Decoding firebase_options.dart from environment variable..."
    echo "$FIREBASE_OPTIONS_BASE64" | base64 --decode > lib/firebase_options.dart
    echo "Successfully recreated lib/firebase_options.dart"
else
    echo "WARNING: FIREBASE_OPTIONS_BASE64 is not set!"
    echo "The app may fail to compile or run if this file is missing."
fi

# 3. Build the Web App
echo "Building Flutter Web..."
flutter config --enable-web
flutter build web --release

echo "Build successful! Output is in build/web"
