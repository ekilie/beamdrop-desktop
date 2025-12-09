#!/bin/bash

# Script to create a DMG file for BeamDrop Desktop
# Usage: ./create-dmg.sh [app-bundle-name]

set -e

# Configuration
APP_NAME="beamdrop-desktop"
APP_DISPLAY_NAME="BeamDrop"
VERSION="0.1.0"
BIN_DIR="bin"
DMG_DIR="dmg"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_DISPLAY_NAME}"

# Allow specifying which app bundle to use (default to .app, fallback to .dev.app)
APP_BUNDLE="${1:-${APP_NAME}.app}"

# If default doesn't exist, try .dev.app
if [ ! -d "${BIN_DIR}/${APP_BUNDLE}" ]; then
    if [ -d "${BIN_DIR}/${APP_NAME}.dev.app" ]; then
        APP_BUNDLE="${APP_NAME}.dev.app"
        echo "INFO: Using development app bundle: ${APP_BUNDLE}"
    elif [ -d "${BIN_DIR}/${APP_NAME}.app" ]; then
        APP_BUNDLE="${APP_NAME}.app"
    else
        echo "ERROR: No app bundle found in ${BIN_DIR}/"
        echo "Available options:"
        echo "   - Run 'task darwin:package' to create ${APP_NAME}.app"
        echo "   - Run 'task darwin:build' and 'task darwin:run' to create ${APP_NAME}.dev.app"
        echo "   - Or specify app bundle: ./create-dmg.sh <bundle-name>"
        exit 1
    fi
fi

echo "Creating DMG for ${APP_DISPLAY_NAME} v${VERSION}"
echo "Using app bundle: ${APP_BUNDLE}"

# Clean up previous DMG artifacts
echo "Cleaning up previous builds..."
rm -rf "${DMG_DIR}"
rm -f "${BIN_DIR}/${DMG_NAME}"
rm -f "${BIN_DIR}/${APP_NAME}-temp.dmg"

# Create temporary DMG directory
echo "Creating temporary DMG directory..."
mkdir -p "${DMG_DIR}"

# Copy app bundle to DMG directory with the proper name (without .dev suffix)
echo "Copying app bundle..."
if [[ "${APP_BUNDLE}" == *".dev.app" ]]; then
    # Copy but rename to final app name
    cp -R "${BIN_DIR}/${APP_BUNDLE}" "${DMG_DIR}/${APP_NAME}.app"
    FINAL_APP_NAME="${APP_NAME}.app"
else
    cp -R "${BIN_DIR}/${APP_BUNDLE}" "${DMG_DIR}/"
    FINAL_APP_NAME="${APP_BUNDLE}"
fi

# Create Applications symlink
echo "Creating Applications symlink..."
ln -s /Applications "${DMG_DIR}/Applications"

# Create a temporary DMG
echo "Creating temporary DMG..."
TEMP_DMG="${BIN_DIR}/${APP_NAME}-temp.dmg"
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDRW \
    "${TEMP_DMG}"

# Mount the temporary DMG
echo "Mounting temporary DMG..."
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
hdiutil attach "${TEMP_DMG}" -readwrite -noverify -noautoopen

# Wait for mount
sleep 2

# Set background and icon positioning
echo "Configuring DMG appearance..."
osascript <<EOF
tell application "Finder"
  tell disk "${VOLUME_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 100, 900, 500}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set position of item "${FINAL_APP_NAME}" of container window to {125, 180}
    set position of item "Applications" of container window to {375, 180}
    update without registering applications
    delay 2
    close
  end tell
end tell
EOF

# Sync to ensure changes are written
sync

# Wait a bit for Finder to finish
sleep 2

# Unmount the temporary DMG
echo "Unmounting temporary DMG..."
hdiutil detach "${MOUNT_DIR}" -force || hdiutil detach "${MOUNT_DIR}"

# Wait for unmount
sleep 1

# Convert to compressed DMG
echo "Compressing DMG..."
hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${BIN_DIR}/${DMG_NAME}"

# Clean up
echo "Cleaning up temporary files..."
rm -f "${TEMP_DMG}"
rm -rf "${DMG_DIR}"

# Print success message
echo "SUCCESS: DMG created successfully!"
echo "Location: ${BIN_DIR}/${DMG_NAME}"
echo "Size: $(du -h "${BIN_DIR}/${DMG_NAME}" | cut -f1)"