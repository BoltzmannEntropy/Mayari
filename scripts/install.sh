#!/bin/bash
# Mayari Installation Script
# Sets up the environment for development (Python-free native Swift TTS)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "Mayari PDF Reader - Installation Script"
echo "(Native Swift TTS - Python-Free)"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is only for macOS"
    exit 1
fi

echo "Step 1: Checking prerequisites..."
echo "-----------------------------------"

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MACOS_MAJOR" -lt 15 ]; then
    print_warning "macOS 15.0+ required for native TTS. Current: $MACOS_VERSION"
    print_warning "The app will build but TTS may not work."
else
    print_status "macOS $MACOS_VERSION (Sequoia or later)"
fi

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    print_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    print_status "Homebrew found"
fi

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    print_error "Flutter not found. Please install Flutter SDK from https://flutter.dev"
    print_error "Or install via: brew install --cask flutter"
    exit 1
else
    FLUTTER_VERSION=$(flutter --version 2>&1 | head -1)
    print_status "Flutter found ($FLUTTER_VERSION)"
fi

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode command line tools not found."
    print_error "Install via: xcode-select --install"
    exit 1
else
    XCODE_VERSION=$(xcodebuild -version | head -1)
    print_status "$XCODE_VERSION"
fi

echo ""
echo "Step 2: Setting up Flutter..."
echo "------------------------------"

cd "$PROJECT_DIR"

# Get Flutter dependencies
echo "Getting Flutter dependencies..."
flutter pub get
print_status "Flutter dependencies installed"

# Disable web support (macOS only app)
flutter config --no-enable-web > /dev/null 2>&1
print_status "Configured for macOS only"

echo ""
echo "Step 3: Adding KokoroSwift Package..."
echo "--------------------------------------"
echo ""
echo "To add KokoroSwift, open the Xcode project and add the package:"
echo ""
echo "  1. Open: macos/Runner.xcworkspace"
echo "  2. File > Add Package Dependencies..."
echo "  3. Enter: https://github.com/mlalma/kokoro-ios"
echo "  4. Select version 1.0.8 or later"
echo "  5. Add to target: Runner"
echo ""
print_warning "Manual step required - see instructions above"

echo ""
echo "Step 4: Setting up mayarictl..."
echo "--------------------------------"

# Make mayarictl executable
if [ -f "$PROJECT_DIR/bin/mayarictl" ]; then
    chmod +x "$PROJECT_DIR/bin/mayarictl"
    print_status "mayarictl configured"
else
    print_warning "mayarictl not found"
fi

echo ""
echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "To run Mayari in development:"
echo "  flutter run -d macos"
echo ""
echo "To build for release:"
echo "  ./scripts/build-dmg.sh"
echo ""
echo "Note: The Kokoro TTS model (~350MB) will download"
echo "automatically on first use."
echo ""
