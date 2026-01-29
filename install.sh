#!/bin/bash
set -e

# --- CONFIGURATION ---
APP_NAME="L1nK"
BUILD_DIR="./build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ASSETS_DIR="./Assets"
VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")

# Signing Configuration
PREFERRED_IDENTITY="Apple Development: Michael Martell (BASSPED38N)"
if [ -z "$SIGNING_IDENTITY" ]; then
    if security find-identity -v -p codesigning | grep -q "$PREFERRED_IDENTITY"; then
        SIGNING_IDENTITY="$PREFERRED_IDENTITY"
    else
        echo "⚠️  Preferred identity '$PREFERRED_IDENTITY' not found."
        echo "   Falling back to ad-hoc signing."
        SIGNING_IDENTITY="-"
    fi
fi

# --- CLEANUP ---
echo "🧹 Cleaning up..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# --- COMPILATION ---
echo "🔨 Compiling Swift sources..."

# Build for Apple Silicon (arm64)
echo "   ...Building for Apple Silicon (arm64)..."
swiftc -o "$MACOS_DIR/$APP_NAME-arm64" \
    L1nkApp.swift ContentView.swift \
    -target arm64-apple-macos14.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework SwiftUI -framework AppKit -framework ServiceManagement -framework UniformTypeIdentifiers -framework LinkPresentation

# Build for Intel (x86_64)
echo "   ...Building for Intel (x86_64)..."
swiftc -o "$MACOS_DIR/$APP_NAME-x86_64" \
    L1nkApp.swift ContentView.swift \
    -target x86_64-apple-macos14.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework SwiftUI -framework AppKit -framework ServiceManagement -framework UniformTypeIdentifiers -framework LinkPresentation

# Create Universal Binary
echo "   ...Creating Universal Binary..."
lipo -create -output "$MACOS_DIR/$APP_NAME" \
    "$MACOS_DIR/$APP_NAME-arm64" \
    "$MACOS_DIR/$APP_NAME-x86_64"

# Cleanup intermediate binaries
rm "$MACOS_DIR/$APP_NAME-arm64"
rm "$MACOS_DIR/$APP_NAME-x86_64"

# --- PLIST & RESOURCES ---
echo "📄 Copying Info.plist..."
cp Info.plist "$CONTENTS_DIR/Info.plist"

# Update Version in Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS_DIR/Info.plist"

echo "🎨 Creating Icon..."
# App Icon from Assets
mkdir -p LinkDocIcon.iconset
sips -z 16 16     "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_16x16.png
sips -z 32 32     "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_16x16@2x.png
sips -z 32 32     "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_32x32.png
sips -z 64 64     "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_32x32@2x.png
sips -z 128 128   "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_128x128.png
sips -z 128 128   "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_128x128@2x.png
sips -z 256 256   "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_256x256.png
sips -z 256 256   "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_256x256@2x.png
sips -z 512 512   "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_512x512.png
sips -z 512 512   "$ASSETS_DIR/LinkDocIcon.png" --out LinkDocIcon.iconset/icon_512x512@2x.png
iconutil -c icns LinkDocIcon.iconset
cp LinkDocIcon.icns "$RESOURCES_DIR/LinkDocIcon.icns"
rm -rf LinkDocIcon.iconset

echo "📱 Creating App Icon..."
mkdir -p AppIcon.iconset
sips -z 16 16     "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 "$ASSETS_DIR/LinkDocIcon.png" --out AppIcon.iconset/icon_512x512@2x.png
iconutil -c icns AppIcon.iconset
cp AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
rm -rf AppIcon.iconset

echo "📺 Creating YouTube Icon..."
# Convert SVG to PNG using helper swift script (preserves transparency)
swift convert_icon.swift "$ASSETS_DIR/YouTube_full-color_icon_(2017).svg" YouTubeIcon.png 1024

mkdir -p YouTubeIcon.iconset
sips -z 16 16     YouTubeIcon.png --out YouTubeIcon.iconset/icon_16x16.png
sips -z 32 32     YouTubeIcon.png --out YouTubeIcon.iconset/icon_16x16@2x.png
sips -z 32 32     YouTubeIcon.png --out YouTubeIcon.iconset/icon_32x32.png
sips -z 64 64     YouTubeIcon.png --out YouTubeIcon.iconset/icon_32x32@2x.png
sips -z 128 128   YouTubeIcon.png --out YouTubeIcon.iconset/icon_128x128.png
sips -z 256 256   YouTubeIcon.png --out YouTubeIcon.iconset/icon_128x128@2x.png
sips -z 256 256   YouTubeIcon.png --out YouTubeIcon.iconset/icon_256x256.png
sips -z 512 512   YouTubeIcon.png --out YouTubeIcon.iconset/icon_256x256@2x.png
sips -z 512 512   YouTubeIcon.png --out YouTubeIcon.iconset/icon_512x512.png
sips -z 1024 1024 YouTubeIcon.png --out YouTubeIcon.iconset/icon_512x512@2x.png
iconutil -c icns YouTubeIcon.iconset
cp YouTubeIcon.icns "$RESOURCES_DIR/YouTubeIcon.icns"
rm -rf YouTubeIcon.iconset
rm YouTubeIcon.png

echo "🐙 Creating GitHub Icon..."
swift convert_icon.swift "$ASSETS_DIR/github-icon-2.svg" GitHubIcon.png 1024

mkdir -p GitHubIcon.iconset
sips -z 16 16     GitHubIcon.png --out GitHubIcon.iconset/icon_16x16.png
sips -z 32 32     GitHubIcon.png --out GitHubIcon.iconset/icon_16x16@2x.png
sips -z 32 32     GitHubIcon.png --out GitHubIcon.iconset/icon_32x32.png
sips -z 64 64     GitHubIcon.png --out GitHubIcon.iconset/icon_32x32@2x.png
sips -z 128 128   GitHubIcon.png --out GitHubIcon.iconset/icon_128x128.png
sips -z 256 256   GitHubIcon.png --out GitHubIcon.iconset/icon_128x128@2x.png
sips -z 256 256   GitHubIcon.png --out GitHubIcon.iconset/icon_256x256.png
sips -z 512 512   GitHubIcon.png --out GitHubIcon.iconset/icon_256x256@2x.png
sips -z 512 512   GitHubIcon.png --out GitHubIcon.iconset/icon_512x512.png
sips -z 1024 1024 GitHubIcon.png --out GitHubIcon.iconset/icon_512x512@2x.png
iconutil -c icns GitHubIcon.iconset
cp GitHubIcon.icns "$RESOURCES_DIR/GitHubIcon.icns"
rm -rf GitHubIcon.iconset
rm GitHubIcon.png

echo "🍏 Creating App Store Icon..."
swift convert_icon.swift "$ASSETS_DIR/apple-app-store.svg" AppStoreIcon.png 1024

mkdir -p AppStoreIcon.iconset
sips -z 16 16     AppStoreIcon.png --out AppStoreIcon.iconset/icon_16x16.png
sips -z 32 32     AppStoreIcon.png --out AppStoreIcon.iconset/icon_16x16@2x.png
sips -z 32 32     AppStoreIcon.png --out AppStoreIcon.iconset/icon_32x32.png
sips -z 64 64     AppStoreIcon.png --out AppStoreIcon.iconset/icon_32x32@2x.png
sips -z 128 128   AppStoreIcon.png --out AppStoreIcon.iconset/icon_128x128.png
sips -z 256 256   AppStoreIcon.png --out AppStoreIcon.iconset/icon_128x128@2x.png
sips -z 256 256   AppStoreIcon.png --out AppStoreIcon.iconset/icon_256x256.png
sips -z 512 512   AppStoreIcon.png --out AppStoreIcon.iconset/icon_256x256@2x.png
sips -z 512 512   AppStoreIcon.png --out AppStoreIcon.iconset/icon_512x512.png
sips -z 1024 1024 AppStoreIcon.png --out AppStoreIcon.iconset/icon_512x512@2x.png
iconutil -c icns AppStoreIcon.iconset
cp AppStoreIcon.icns "$RESOURCES_DIR/AppStoreIcon.icns"
rm -rf AppStoreIcon.iconset
rm AppStoreIcon.png

echo "▶️ Creating Vimeo Icon..."
# Input is already PNG, but let's normalize it
cp "$ASSETS_DIR/Vimeo_icon_block.svg.png" VimeoIcon_source.png
swift convert_icon.swift "VimeoIcon_source.png" VimeoIcon.png 1024
rm VimeoIcon_source.png

mkdir -p VimeoIcon.iconset
sips -z 16 16     VimeoIcon.png --out VimeoIcon.iconset/icon_16x16.png
sips -z 32 32     VimeoIcon.png --out VimeoIcon.iconset/icon_16x16@2x.png
sips -z 32 32     VimeoIcon.png --out VimeoIcon.iconset/icon_32x32.png
sips -z 64 64     VimeoIcon.png --out VimeoIcon.iconset/icon_32x32@2x.png
sips -z 128 128   VimeoIcon.png --out VimeoIcon.iconset/icon_128x128.png
sips -z 256 256   VimeoIcon.png --out VimeoIcon.iconset/icon_128x128@2x.png
sips -z 256 256   VimeoIcon.png --out VimeoIcon.iconset/icon_256x256.png
sips -z 512 512   VimeoIcon.png --out VimeoIcon.iconset/icon_256x256@2x.png
sips -z 512 512   VimeoIcon.png --out VimeoIcon.iconset/icon_512x512.png
sips -z 1024 1024 VimeoIcon.png --out VimeoIcon.iconset/icon_512x512@2x.png
iconutil -c icns VimeoIcon.iconset
cp VimeoIcon.icns "$RESOURCES_DIR/VimeoIcon.icns"
rm -rf VimeoIcon.iconset
rm VimeoIcon.png

echo "🔐 Signing app (Identity: $SIGNING_IDENTITY)..."
codesign --force --deep --sign "$SIGNING_IDENTITY" --entitlements L1nk.entitlements "$APP_BUNDLE"

echo "📦 Creating DMG..."
if [ -f "$BUILD_DIR/$APP_NAME.dmg" ]; then
    rm "$BUILD_DIR/$APP_NAME.dmg"
fi

# Create a temporary folder for DMG contents
DMG_TMP="dmg_tmp"
mkdir -p "$DMG_TMP"
cp -r "$APP_BUNDLE" "$DMG_TMP/"
ln -s /Applications "$DMG_TMP/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$DMG_TMP" -ov -format UDZO "$BUILD_DIR/$APP_NAME.dmg"

# Cleanup
rm -rf "$DMG_TMP"

echo "✅ Build complete!"
echo "📂 App is located at: $APP_BUNDLE"
echo "💿 DMG is located at: $BUILD_DIR/$APP_NAME.dmg"
open "$BUILD_DIR"
