#!/bin/bash

# Script to create a DMG file for BeamDrop Desktop
# Usage: ./create-dmg.sh

set -e

# Configuration
APP_NAME="beamdrop-desktop"
APP_DISPLAY_NAME="BeamDrop"
VERSION="0.1.0"
BIN_DIR="bin"
DMG_DIR="dmg"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_DISPLAY_NAME}"

echo "🚀 Creating DMG for ${APP_DISPLAY_NAME} v${VERSION}"

# Check if .app bundle exists
if [ ! -d "${BIN_DIR}/${APP_NAME}.app" ]; then
    echo "❌ Error: ${BIN_DIR}/${APP_NAME}.app not found"
    echo "💡 Run 'task darwin:package' first to build the app bundle"
    exit 1
fi

# Clean up previous DMG artifacts
echo "🧹 Cleaning up previous builds..."
rm -rf "${DMG_DIR}"
rm -f "${BIN_DIR}/${DMG_NAME}"

# Create temporary DMG directory
echo "📁 Creating temporary DMG directory..."
mkdir -p "${DMG_DIR}"

# Copy app bundle to DMG directory
echo "📦 Copying app bundle..."
cp -R "${BIN_DIR}/${APP_NAME}.app" "${DMG_DIR}/"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "${DMG_DIR}/Applications"

# Create a temporary DMG
echo "🎨 Creating temporary DMG..."
TEMP_DMG="${BIN_DIR}/${APP_NAME}-temp.dmg"
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDRW \
    "${TEMP_DMG}"

# Mount the temporary DMG
echo "💿 Mounting temporary DMG..."
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "${TEMP_DMG}" -readwrite -noverify -noautoopen

# Wait for mount
sleep 2

# Set background and icon positioning (optional)
echo "🎨 Configuring DMG appearance..."
echo '
   tell application "Finder"
     tell disk "'${VOLUME_NAME}'"
           open
           set current view of container window to icon view
           set toolbar visible of container window to false
           set statusbar visible of container window to false
           set the bounds of container window to {400, 100, 900, 500}
           set viewOptions to the icon view options of container window
           set arrangement of viewOptions to not arranged
           set icon size of viewOptions to 128
           set position of item "'${APP_NAME}'.app" of container window to {125, 180}
           set position of item "Applications" of container window to {375, 180}
           update without registering applications
           delay 2
           close
     end tell
   end tell
' | osascript

# Unmount the temporary DMG
echo "⏏️  Unmounting temporary DMG..."
hdiutil detach "${MOUNT_DIR}" -force

# Convert to compressed DMG
echo "🗜️  Compressing DMG..."
hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${BIN_DIR}/${DMG_NAME}"

# Clean up
echo "🧹 Cleaning up temporary files..."
rm -f "${TEMP_DMG}"
rm -rf "${DMG_DIR}"

# Print success message
echo "✅ DMG created successfully!"
echo "📍 Location: ${BIN_DIR}/${DMG_NAME}"
echo "📊 Size: $(du -h "${BIN_DIR}/${DMG_NAME}" | cut -f1)"
