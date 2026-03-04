#!/bin/bash

# Exit on error
set -e

APP_NAME="MacleanApp"
BUILD_DIR=".build/release"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"

echo "Building Maclean CLI and GUI in release mode..."
swift build -c release

echo "Packaging ${APP_NAME}.app..."

# Create necessary directories
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy the executable into the bundle
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

# Create a basic Info.plist
cat > "${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.maclean.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.3</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Successfully created ${APP_DIR}!"

echo "Zipping for release..."
cd "${BUILD_DIR}"
zip -r -q "${APP_NAME}.zip" "${APP_NAME}.app"
echo "Successfully created ${BUILD_DIR}/${APP_NAME}.zip!"
echo "You can now run it: open ${APP_DIR}"
