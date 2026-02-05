#!/bin/bash
#
# Bundle Kokoro TTS for Mayari
# Downloads models and creates a standalone Python environment
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KOKORO_DIR="$PROJECT_DIR/macos/Runner/Resources/kokoro"

echo "=== Kokoro TTS Bundler for Mayari ==="
echo "Project: $PROJECT_DIR"
echo "Kokoro dir: $KOKORO_DIR"
echo ""

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required. Install via: brew install python"
    exit 1
fi

# Create kokoro directory if needed
mkdir -p "$KOKORO_DIR"

# Create virtual environment for bundled Python
VENV_DIR="$KOKORO_DIR/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate venv and install dependencies
echo "Installing Kokoro dependencies..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip --quiet
pip install kokoro-onnx --quiet
deactivate

# Download ONNX models from Hugging Face
MODEL_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

MODEL_FILE="$KOKORO_DIR/kokoro-v1.0.onnx"
VOICES_FILE="$KOKORO_DIR/voices-v1.0.bin"

if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading Kokoro ONNX model (~350MB)..."
    curl -L -o "$MODEL_FILE" "$MODEL_URL"
else
    echo "Model already exists: $MODEL_FILE"
fi

if [ ! -f "$VOICES_FILE" ]; then
    echo "Downloading voice embeddings (~5MB)..."
    curl -L -o "$VOICES_FILE" "$VOICES_URL"
else
    echo "Voices already exist: $VOICES_FILE"
fi

# Create launcher script
LAUNCHER="$KOKORO_DIR/start_server.sh"
cat > "$LAUNCHER" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/venv/bin/activate"
python3 "$SCRIPT_DIR/kokoro_server.py" "$@"
EOF
chmod +x "$LAUNCHER"

echo ""
echo "=== Kokoro TTS Setup Complete ==="
echo ""
echo "Files created:"
echo "  - $MODEL_FILE"
echo "  - $VOICES_FILE"
echo "  - $VENV_DIR (Python environment)"
echo "  - $LAUNCHER"
echo ""
echo "To test the server manually:"
echo "  $LAUNCHER --port 8787"
echo ""
echo "Available British voices:"
echo "  Female: bf_emma (best), bf_isabella, bf_alice, bf_lily"
echo "  Male: bm_george, bm_fable, bm_lewis, bm_daniel"
