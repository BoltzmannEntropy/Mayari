#!/bin/bash
# Mayari Installation Script
# Installs all dependencies and sets up the environment for development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_DIR/backend"

echo "========================================"
echo "Mayari PDF Reader - Installation Script"
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

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    print_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    print_status "Homebrew found"
fi

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    print_warning "Python 3 not found. Installing..."
    brew install python@3.11
else
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    print_status "Python 3 found (version $PYTHON_VERSION)"
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

echo ""
echo "Step 2: Setting up Python backend..."
echo "-------------------------------------"

# Create backend virtual environment
if [ ! -d "$BACKEND_DIR/.venv" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$BACKEND_DIR/.venv"
    print_status "Virtual environment created"
else
    print_status "Virtual environment already exists"
fi

# Activate and install dependencies
echo "Installing Python dependencies..."
source "$BACKEND_DIR/.venv/bin/activate"

# Upgrade pip
pip install --upgrade pip > /dev/null 2>&1

# Install requirements
if [ -f "$BACKEND_DIR/requirements.txt" ]; then
    pip install -r "$BACKEND_DIR/requirements.txt"
    print_status "Python dependencies installed"
else
    print_warning "requirements.txt not found, installing defaults..."
    pip install fastapi uvicorn pydantic soundfile numpy kokoro
fi

deactivate

echo ""
echo "Step 3: Setting up Flutter..."
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
echo "Step 4: Setting up mayarictl..."
echo "--------------------------------"

# Make mayarictl executable
chmod +x "$PROJECT_DIR/bin/mayarictl"
print_status "mayarictl configured"

# Create symbolic link in /usr/local/bin if desired
if [ -d "/usr/local/bin" ]; then
    if [ ! -L "/usr/local/bin/mayarictl" ]; then
        echo "Do you want to create a symlink in /usr/local/bin for global access? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo ln -sf "$PROJECT_DIR/bin/mayarictl" /usr/local/bin/mayarictl
            print_status "Symlink created at /usr/local/bin/mayarictl"
        fi
    else
        print_status "Symlink already exists at /usr/local/bin/mayarictl"
    fi
fi

echo ""
echo "Step 5: First-time Kokoro model download..."
echo "--------------------------------------------"
echo "Note: The Kokoro TTS model will download automatically on first use."
echo "This may take a few minutes depending on your internet connection."
echo ""

echo "========================================"
echo "Installation Complete!"
echo "========================================"
echo ""
echo "To start Mayari:"
echo "  1. Start the TTS server:  mayarictl tts start"
echo "  2. Run the app:           mayarictl run"
echo ""
echo "Or run both with:          mayarictl start"
echo ""
echo "For help:                  mayarictl help"
echo ""
