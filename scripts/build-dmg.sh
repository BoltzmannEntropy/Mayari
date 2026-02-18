#!/bin/bash
# Mayari DMG Builder Script
# Creates a distributable DMG file for macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DMG_DIR="$BUILD_DIR/dmg"
RELEASE_DIR="$BUILD_DIR/macos/Build/Products/Release"
APP_NAME="Mayari"
DMG_NAME="Mayari"
VERSION=$(grep 'version:' "$PROJECT_DIR/pubspec.yaml" | head -1 | cut -d'+' -f1 | cut -d':' -f2 | xargs)

echo "========================================"
echo "Mayari DMG Builder"
echo "Version: $VERSION"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is only for macOS"
    exit 1
fi

# Check for create-dmg (optional but recommended)
HAS_CREATE_DMG=false
if command -v create-dmg &> /dev/null; then
    HAS_CREATE_DMG=true
    print_status "create-dmg found"
else
    print_warning "create-dmg not found. Using basic DMG creation."
    print_warning "For prettier DMGs, install: brew install create-dmg"
fi

echo ""
echo "Step 1: Building Release App..."
echo "--------------------------------"

cd "$PROJECT_DIR"

# Clean previous build
echo "Cleaning previous build..."
flutter clean > /dev/null 2>&1
flutter pub get > /dev/null

# Build release
echo "Building release app (this may take a few minutes)..."
flutter build macos --release

if [ ! -d "$RELEASE_DIR/$APP_NAME.app" ]; then
    # Try alternative app name (mayari_temp.app)
    if [ -d "$RELEASE_DIR/mayari_temp.app" ]; then
        mv "$RELEASE_DIR/mayari_temp.app" "$RELEASE_DIR/$APP_NAME.app"
    else
        print_error "App not found in $RELEASE_DIR"
        exit 1
    fi
fi

print_status "Release app built"

echo ""
echo "Step 2: Preparing DMG Contents..."
echo "----------------------------------"

# Clean and create DMG directory
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app
cp -R "$RELEASE_DIR/$APP_NAME.app" "$DMG_DIR/"
print_status "App copied to DMG staging"

# Embed license files in the app bundle
RESOURCES_DIR="$DMG_DIR/$APP_NAME.app/Contents/Resources"
if [ -f "$PROJECT_DIR/LICENSE" ]; then
    cp "$PROJECT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE"
fi
if [ -f "$PROJECT_DIR/BINARY-LICENSE.txt" ]; then
    cp "$PROJECT_DIR/BINARY-LICENSE.txt" "$RESOURCES_DIR/BINARY-LICENSE.txt"
fi

# Copy license files to DMG root
if [ -f "$PROJECT_DIR/LICENSE" ]; then
    cp "$PROJECT_DIR/LICENSE" "$DMG_DIR/LICENSE"
fi
if [ -f "$PROJECT_DIR/BINARY-LICENSE.txt" ]; then
    cp "$PROJECT_DIR/BINARY-LICENSE.txt" "$DMG_DIR/BINARY-LICENSE.txt"
fi

# Copy backend files
mkdir -p "$DMG_DIR/Backend"
cp -R "$PROJECT_DIR/backend/"* "$DMG_DIR/Backend/"
print_status "Backend files copied"

# Copy mayarictl
cp "$PROJECT_DIR/bin/mayarictl" "$DMG_DIR/"
chmod +x "$DMG_DIR/mayarictl"
print_status "mayarictl copied"

# Create README for DMG
cat > "$DMG_DIR/README.txt" << 'EOF'
Mayari PDF Reader with Kokoro TTS
=================================

Installation:
1. Drag "Mayari.app" to your Applications folder
2. Copy the "Backend" folder to ~/Library/Application Support/Mayari/
3. Copy "mayarictl" to /usr/local/bin/ (optional, for CLI access)

First-time Setup:
1. Open Terminal
2. Run: mayarictl install  (or use the Backend setup)
3. Run: mayarictl tts start
4. Launch Mayari.app

Usage:
- mayarictl start    - Start both TTS server and app
- mayarictl tts start - Start TTS server only
- mayarictl run      - Run the app only
- mayarictl help     - Show all commands

Note: The Kokoro TTS model will download automatically on first use.
This requires ~500MB of disk space and internet connection.

For more information, visit the project repository.
EOF

print_status "README created"

# Create Applications symlink
ln -sf /Applications "$DMG_DIR/Applications"
print_status "Applications symlink created"

echo ""
echo "Step 3: Creating DMG..."
echo "------------------------"

DMG_OUTPUT="$BUILD_DIR/${DMG_NAME}-${VERSION}.dmg"
rm -f "$DMG_OUTPUT"

if [ "$HAS_CREATE_DMG" = true ]; then
    # Use create-dmg for a nice DMG
    create-dmg \
        --volname "$APP_NAME $VERSION" \
        --volicon "$PROJECT_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 150 190 \
        --icon "Applications" 450 190 \
        --icon "Backend" 300 300 \
        --icon "mayarictl" 150 300 \
        --icon "README.txt" 450 300 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 450 190 \
        "$DMG_OUTPUT" \
        "$DMG_DIR" \
        2>/dev/null || {
            print_warning "create-dmg failed, falling back to basic DMG"
            HAS_CREATE_DMG=false
        }
fi

if [ "$HAS_CREATE_DMG" = false ]; then
    # Basic DMG creation
    hdiutil create -volname "$APP_NAME $VERSION" \
        -srcfolder "$DMG_DIR" \
        -ov -format UDZO \
        "$DMG_OUTPUT"
fi

print_status "DMG created: $DMG_OUTPUT"

echo ""
echo "Step 4: Cleanup..."
echo "-------------------"

# Optionally clean up staging directory
# rm -rf "$DMG_DIR"
print_status "DMG staging kept at: $DMG_DIR"

echo ""
echo "========================================"
echo "Build Complete!"
echo "========================================"
echo ""
echo "DMG file: $DMG_OUTPUT"
echo "Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
echo ""
echo "To test the DMG:"
echo "  open $DMG_OUTPUT"
echo ""
