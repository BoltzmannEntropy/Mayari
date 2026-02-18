#!/usr/bin/env bash
# =============================================================================
# Mayari - Release Script
# =============================================================================
# Creates a macOS DMG, uploads to GitHub releases, and updates the website.
#
# Usage:
#   ./scripts/release.sh                    # Build DMG only
#   ./scripts/release.sh --upload           # Build and upload to GitHub
#   ./scripts/release.sh --sync-website     # Build and update website
#   ./scripts/release.sh --upload --sync-website  # Full release
#
# Examples:
#   ./scripts/release.sh --upload --sync-website
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
WEBSITE_DIR="$(dirname "$PROJECT_DIR")/MayariWEB"

# App info
APP_NAME="Mayari"
VERSION=$(grep 'version:' "$PROJECT_DIR/pubspec.yaml" | head -1 | cut -d'+' -f1 | cut -d':' -f2 | xargs)
UPLOAD_TO_GITHUB=false
SYNC_WEBSITE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --upload)
            UPLOAD_TO_GITHUB=true
            ;;
        --sync-website)
            SYNC_WEBSITE=true
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}$*${NC}"; }
ok()    { echo -e "${GREEN}✓ $*${NC}"; }
warn()  { echo -e "${YELLOW}$*${NC}"; }
fail()  { echo -e "${RED}✗ $*${NC}"; exit 1; }

# =============================================================================
# Build DMG
# =============================================================================
info "=== Mayari Release Script ==="
echo ""
info "Version: $VERSION"
info "Upload to GitHub: $UPLOAD_TO_GITHUB"
info "Sync website: $SYNC_WEBSITE"
echo ""

info "Building DMG..."
"$SCRIPT_DIR/build-dmg.sh"

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$PROJECT_DIR/dist/$DMG_NAME"
if [ ! -f "$DMG_PATH" ]; then
    DMG_PATH="$BUILD_DIR/$DMG_NAME"
fi

if [ ! -f "$DMG_PATH" ]; then
    fail "DMG not found: $DMG_PATH"
fi
ok "DMG ready: $DMG_PATH"

# =============================================================================
# Generate SHA256 Checksum
# =============================================================================
info ""
info "Generating SHA256 checksum..."
DMG_DIR="$(dirname "$DMG_PATH")"
cd "$DMG_DIR"
shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
SHA256=$(cat "$DMG_NAME.sha256")
ok "Checksum: $SHA256"

# =============================================================================
# Upload to GitHub Release (if --upload flag)
# =============================================================================
if [ "$UPLOAD_TO_GITHUB" = true ]; then
    info ""
    info "Uploading to GitHub Release..."

    # Check gh CLI
    if ! command -v gh &> /dev/null; then
        fail "GitHub CLI (gh) not found. Install with: brew install gh"
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        fail "Not authenticated with GitHub. Run: gh auth login"
    fi

    cd "$PROJECT_DIR"
    TAG="v$VERSION"

    # Check if release exists, create if not
    if ! gh release view "$TAG" &> /dev/null; then
        info "Creating release $TAG..."
        gh release create "$TAG" \
            --title "$APP_NAME $VERSION" \
            --notes "## $APP_NAME $VERSION

### Features
- PDF document viewing with smooth navigation
- Text-to-speech using Kokoro TTS engine
- Multiple voice selection with speaker cards
- Dual-provider licensing (BSL + Binary License)

### Installation
1. Download the DMG file
2. Open it and drag Mayari to Applications
3. On first launch, right-click and select Open (macOS Gatekeeper)
4. The bundled audio backend starts automatically inside the app

### System Requirements
- macOS 12.0 or later (Apple Silicon recommended)
- ~500MB disk space for TTS models

### Checksums
\`\`\`
$SHA256
\`\`\`

---
Generated with [Claude Code](https://claude.ai/code)
" \
            --draft
        ok "Release $TAG created as draft"
    fi

    # Upload assets
    info "Uploading DMG..."
    gh release upload "$TAG" "$DMG_PATH" --clobber
    ok "Uploaded: $DMG_NAME"

    info "Uploading checksum..."
    gh release upload "$TAG" "$DMG_DIR/$DMG_NAME.sha256" --clobber
    ok "Uploaded: $DMG_NAME.sha256"

    echo ""
    echo -e "${GREEN}=== Upload Complete ===${NC}"
    echo "Release URL: $(gh release view "$TAG" --json url -q .url)"
    echo ""
    echo -e "${YELLOW}Note: Release is created as DRAFT. Publish it manually on GitHub.${NC}"
fi

# =============================================================================
# Sync Website (if --sync-website flag)
# =============================================================================
if [ "$SYNC_WEBSITE" = true ]; then
    info ""
    info "Syncing website with release v$VERSION..."

    WEBSITE_INDEX="$WEBSITE_DIR/index.html"

    if [ ! -f "$WEBSITE_INDEX" ]; then
        warn "Website not found at $WEBSITE_DIR. Skipping website sync."
    else
        # Update download URLs (replace any version pattern)
        sed -i '' -E "s|/releases/download/v[0-9]+\.[0-9]+\.[0-9]+/Mayari-[0-9]+\.[0-9]+\.[0-9]+\.dmg|/releases/download/v$VERSION/Mayari-$VERSION.dmg|g" "$WEBSITE_INDEX"
        ok "Updated download URLs to v$VERSION"

        # Update version display text
        sed -i '' -E "s|v[0-9]+\.[0-9]+\.[0-9]+ &bull; macOS|v$VERSION \&bull; macOS|g" "$WEBSITE_INDEX"
        ok "Updated version display to v$VERSION"

        # Commit and push website changes
        cd "$WEBSITE_DIR"
        if git diff --quiet; then
            info "No website changes to commit"
        else
            git add index.html
            git commit -m "Update to v$VERSION"
            git push
            ok "Website changes pushed to GitHub"
        fi
        cd "$PROJECT_DIR"

        echo ""
        echo -e "${GREEN}=== Website Synced ===${NC}"
        echo "Website will update shortly at: https://boltzmannentropy.github.io/mayari-web/"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}=== Release Complete ===${NC}"
echo ""
echo "DMG:      $DMG_PATH"
echo "Size:     $(du -h "$DMG_PATH" | cut -f1)"
echo "Checksum: $DMG_DIR/$DMG_NAME.sha256"
echo ""

if [ "$UPLOAD_TO_GITHUB" = false ] || [ "$SYNC_WEBSITE" = false ]; then
    echo "Additional options:"
    if [ "$UPLOAD_TO_GITHUB" = false ]; then
        echo "  --upload        Upload to GitHub Releases"
    fi
    if [ "$SYNC_WEBSITE" = false ]; then
        echo "  --sync-website  Update website download links"
    fi
    echo ""
    echo "Full release command:"
    echo "  ./scripts/release.sh --upload --sync-website"
    echo ""
fi
