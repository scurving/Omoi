#!/bin/bash
set -e

# Configuration
APP_NAME="Omoi"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
SOURCE_PLIST="Sources/Omoi/Info.plist"
INSTALL_PATH="/Applications/$APP_BUNDLE"
DATA_DIR="$HOME/Documents/Omoi"
PREBUILD_BACKUP_DIR="$DATA_DIR/pre-build-backups"

# Parse arguments
CLEAN_BUILD=false
if [[ "$1" == "--clean" ]]; then
    CLEAN_BUILD=true
    echo "🧹 Clean build requested"
fi

# ============================================
# PRE-BUILD DATA BACKUP (Protects your history!)
# ============================================
backup_user_data() {
    if [ -d "$DATA_DIR" ]; then
        mkdir -p "$PREBUILD_BACKUP_DIR"
        TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
        BACKUP_FOLDER="$PREBUILD_BACKUP_DIR/backup_$TIMESTAMP"
        mkdir -p "$BACKUP_FOLDER"

        echo "🛡️  Backing up user data before build..."

        # Backup history.json
        if [ -f "$DATA_DIR/history.json" ]; then
            cp "$DATA_DIR/history.json" "$BACKUP_FOLDER/"
            HISTORY_SIZE=$(wc -c < "$DATA_DIR/history.json" | tr -d ' ')
            echo "   ✅ history.json ($HISTORY_SIZE bytes)"
        fi

        # Backup goals.json
        if [ -f "$DATA_DIR/goals.json" ]; then
            cp "$DATA_DIR/goals.json" "$BACKUP_FOLDER/"
            echo "   ✅ goals.json"
        fi

        echo "   📁 Backup saved to: $BACKUP_FOLDER"

        BACKUP_COUNT=$(ls -d "$PREBUILD_BACKUP_DIR"/backup_* 2>/dev/null | wc -l | tr -d ' ')
        echo "   ℹ️  Total pre-build backups: $BACKUP_COUNT (keeping all)"
    else
        echo "ℹ️  No existing data directory found (first build)"
    fi
}

# Run backup before anything else
backup_user_data
echo ""

# Optional: Clean .build cache for fresh start
if [ "$CLEAN_BUILD" = true ]; then
    echo "🧹 Removing .build cache..."
    rm -rf .build
fi

# 0. Close existing instance
echo "🛑 Closing existing $APP_NAME..."
pkill -x "$APP_NAME" || true

echo "🚀 Building $APP_NAME..."

# 1. Build the executable
swift build -c release --product $APP_NAME

# 2. Create the App Bundle structure
echo "📦 Creating App Bundle..."
if [ -d "$APP_BUNDLE" ]; then
    rm -rf "$APP_BUNDLE"
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy the executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# 4. Create/Process Info.plist
# We need to manually replace variables since we aren't using Xcode
sed -e "s/\$(EXECUTABLE_NAME)/$APP_NAME/" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.wisprrd.$APP_NAME/" \
    -e "s/\$(PRODUCT_NAME)/$APP_NAME/" \
    -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/14.0/" \
    "$SOURCE_PLIST" > "$APP_BUNDLE/Contents/Info.plist"

# 5. Ad-hoc Code Signing & Permissions
# Essential for Accessibility permissions to stick
echo "🔐 Signing App..."
codesign --force --deep --sign - --entitlements Omoi.entitlements "$APP_BUNDLE"

echo "✅ Build Complete!"

# 6. Install to /Applications for stable permissions
if [ -d "$INSTALL_PATH" ]; then
    echo "📦 Updating existing installation..."
    rm -rf "$INSTALL_PATH"
else
    echo "📦 Installing to /Applications..."
fi

cp -R "$APP_BUNDLE" "/Applications/"
echo "   ✅ Installed to: $INSTALL_PATH"

# 7. Clean up temporary bundle from project directory
echo "🧹 Cleaning up project directory..."
rm -rf "$APP_BUNDLE"
echo "   ✅ Removed temporary $APP_BUNDLE from project"

# Optional: Show .build size (for user awareness)
if [ -d ".build" ]; then
    BUILD_SIZE=$(du -sh .build | cut -f1)
    echo "   ℹ️  .build cache: $BUILD_SIZE (preserving for faster rebuilds)"
    echo "   💡 Run './build_app.sh --clean' to remove cache and do full rebuild"
fi

echo ""
echo "⚠️  IMPORTANT: Grant Accessibility Permission (ONE TIME)"
echo "Since the app is now in /Applications, permissions will persist across rebuilds."
echo ""
echo "To enable auto-paste:"
echo "1. System Settings → Privacy & Security → Accessibility"
echo "2. Find 'Omoi' and toggle it ON"
echo "3. This only needs to be done ONCE (not after every rebuild)"
echo ""
echo "🚀 Launching $APP_NAME from /Applications..."
open "$INSTALL_PATH"
