#!/bin/bash
set -e

HYPERMAC_RELEASE_TAG="${HYPERMAC_RELEASE_TAG:-latest}"
if [[ ! "${HYPERMAC_RELEASE_TAG}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "❌ Invalid HYPERMAC_RELEASE_TAG: ${HYPERMAC_RELEASE_TAG}"
    exit 2
fi
HYPERMAC_BUILD_COMMIT="${HYPERMAC_BUILD_COMMIT:-$(git rev-parse --verify HEAD 2>/dev/null || true)}"
if [ "${CI:-}" = "true" ] && [[ ! "${HYPERMAC_BUILD_COMMIT}" =~ ^[0-9a-f]{40}$ ]]; then
    echo "❌ CI build requires a full Git commit SHA."
    exit 2
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          HyperMac — Build Script         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Step 1: Build (Default: Apple Silicon chip M / Optional: --universal) ──
BUILD_UNIVERSAL=false
for arg in "$@"; do
    case "$arg" in
        --universal) BUILD_UNIVERSAL=true ;;
        --no-run) ;; # Tương thích lệnh cũ; build luôn không cài/chạy app.
        *) echo "❌ Unknown option: $arg"; exit 2 ;;
    esac
done

BUILD_DIR="build"
FINAL_APP="${BUILD_DIR}/HyperMac.app"

# Không ghi đè bundle đang chạy: app có thể đọc Resources từ đường dẫn này sau khi mở.
build_app_is_running() {
    [ -f "${FINAL_APP}/Contents/MacOS/HyperMac" ] &&
        /usr/sbin/lsof -t "${FINAL_APP}/Contents/MacOS/HyperMac" 2>/dev/null | /usr/bin/grep -q .
}
if build_app_is_running; then
    echo "❌ HyperMac đang chạy từ ${FINAL_APP}. Hãy mở bản app ở vị trí khác trước khi build."
    exit 2
fi

# Local build phải dùng identity cố định để giữ quyền Accessibility sau cập nhật.
SIGN_IDENTITY="${HYPERMAC_SIGN_IDENTITY:-HyperMac Self-Signed}"
SIGN_KEYCHAIN="${HYPERMAC_SIGN_KEYCHAIN:-}"
FIND_ARGS=()
if [[ -n "${SIGN_KEYCHAIN}" ]]; then
    FIND_ARGS=("${SIGN_KEYCHAIN}")
fi
SIGN_AVAILABLE=false
if security find-identity -p codesigning "${FIND_ARGS[@]}" 2>/dev/null | grep -qF "${SIGN_IDENTITY}"; then
    SIGN_AVAILABLE=true
elif [ "${CI:-}" != "true" ]; then
    echo "❌ Không tìm thấy identity '${SIGN_IDENTITY}'. Dừng trước khi tạo bản app mới."
    echo "   Khôi phục identity cố định rồi chạy lại ./build.sh."
    exit 2
fi

if [ "$BUILD_UNIVERSAL" = "true" ]; then
    echo "🔨 Building HyperMac (Release - Universal 2: arm64 + x86_64)..."
    mkdir -p .build/bin_arm64 .build/bin_x86_64 .build/release
    rm -f .build/bin_arm64/HyperMac .build/bin_x86_64/HyperMac
    rm -f .build/out/Products/Release/HyperMac .build/release/HyperMac
    echo "  -> Compiling arm64 (Apple Silicon)..."
    if ! swift build -c release --disable-sandbox -debug-info-format none --triple arm64-apple-macosx; then
        echo "❌ Không biên dịch được binary arm64."
        exit 1
    fi
    if [ -f ".build/out/Products/Release/HyperMac" ]; then
        cp .build/out/Products/Release/HyperMac .build/bin_arm64/HyperMac
    elif [ -f ".build/release/HyperMac" ]; then
        cp .build/release/HyperMac .build/bin_arm64/HyperMac
    else
        echo "❌ Không tìm thấy binary arm64 sau khi biên dịch."
        exit 1
    fi
    if ! lipo .build/bin_arm64/HyperMac -verify_arch arm64; then
        echo "❌ Binary arm64 không chứa kiến trúc arm64: $(lipo -archs .build/bin_arm64/HyperMac 2>&1)"
        exit 1
    fi

    echo "  -> Compiling x86_64 (Intel)..."
    rm -f .build/out/Products/Release/HyperMac .build/release/HyperMac
    if ! swift build -c release --disable-sandbox -debug-info-format none --triple x86_64-apple-macosx; then
        echo "❌ Không biên dịch được binary x86_64."
        exit 1
    fi
    if [ -f ".build/out/Products/Release/HyperMac" ]; then
        cp .build/out/Products/Release/HyperMac .build/bin_x86_64/HyperMac
    elif [ -f ".build/release/HyperMac" ]; then
        cp .build/release/HyperMac .build/bin_x86_64/HyperMac
    else
        echo "❌ Không tìm thấy binary x86_64 sau khi biên dịch."
        exit 1
    fi
    if ! lipo .build/bin_x86_64/HyperMac -verify_arch x86_64; then
        echo "❌ Binary Intel không chứa kiến trúc x86_64: $(lipo -archs .build/bin_x86_64/HyperMac 2>&1)"
        exit 1
    fi

    BINARY=".build/release/HyperMac"
    echo "  -> Merging with lipo (Universal 2)..."
    lipo -create .build/bin_arm64/HyperMac .build/bin_x86_64/HyperMac -output "$BINARY"
    if ! lipo "$BINARY" -verify_arch arm64 || ! lipo "$BINARY" -verify_arch x86_64; then
        echo "❌ Binary Universal 2 không đủ hai kiến trúc: $(lipo -archs "$BINARY" 2>&1)"
        exit 1
    fi
else
    echo "⚡ Building HyperMac (Tốc độ cao - Chip M: M1/M2/M3/M4)..."
    swift build -c release --disable-sandbox -debug-info-format none
    BINARY=".build/release/HyperMac"
fi

if [ ! -f "$BINARY" ]; then
    echo "❌ Build failed – binary not found."
    exit 1
fi
echo "✅ Build succeeded: $(file "$BINARY")"

# ── Step 2: Create .app bundle ──
APP_NAME="HyperMac"
mkdir -p "${BUILD_DIR}"
STAGING_DIR="$(mktemp -d "${BUILD_DIR}/.hypermac-stage.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT
APP_DIR="${STAGING_DIR}/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "📦 Creating app bundle..."
mkdir -p "${MACOS}" "${RESOURCES}"

cp "$BINARY" "${MACOS}/"

# Copy Resources (AppIcon.icns, cover.jpg, SMC tools, etc.)
if [ -d "Resources" ]; then
    echo "🎨 Copying app resources (icons, cover image, SMC tools)..."
    cp -R Resources/* "${RESOURCES}/"
    chmod +x "${RESOURCES}/smc" "${RESOURCES}/displaycontrol-power" "${RESOURCES}/install-helper.sh" 2>/dev/null || true
fi
if [ -f "LICENSE" ]; then
    cp "LICENSE" "${RESOURCES}/LICENSE"
fi

# Info.plist — LSUIElement hides dock icon (menu-bar only)
cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>HyperMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.opensource.hypermac</string>
    <key>CFBundleName</key>
    <string>HyperMac</string>
    <key>CFBundleDisplayName</key>
    <string>HyperMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Nguyễn Khắc Đại. Licensed under GNU GPLv3.</string>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>HyperMac sử dụng Bluetooth để tự động ngắt kết nối khi gập nắp máy (Sleep Guard), giúp chống tụt pin và chống nóng máy khi ngủ.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>HyperMac quản lý nguồn Bluetooth khi máy Mac vào chế độ ngủ để tiết kiệm pin.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>HyperMac cần quyền ghi màn hình để hiển thị ảnh xem trước các cửa sổ trong trình chuyển đổi Alt+Tab.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>HyperMac sử dụng AppleEvents để điều khiển các ứng dụng và màn hình.</string>
    <key>NSAudioCaptureUsageDescription</key>
    <string>HyperMac cần quyền ghi âm thanh hệ thống để chỉnh âm lượng riêng từng ứng dụng.</string>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Add :HyperMacReleaseTag string ${HYPERMAC_RELEASE_TAG}" "${CONTENTS}/Info.plist"
if [[ "${HYPERMAC_BUILD_COMMIT}" =~ ^[0-9a-f]{40}$ ]]; then
    /usr/bin/plutil -insert HyperMacBuildCommit -string "$HYPERMAC_BUILD_COMMIT" "${CONTENTS}/Info.plist"
fi

# Local builds remember their source bundle so the in-app updater can compare
# the running copy with build/HyperMac.app. CI artifacts stay portable.
if [ "${CI:-}" != "true" ]; then
    LOCAL_BUILD_APP_PATH="$(cd "$BUILD_DIR" && pwd)/${APP_NAME}.app"
    /usr/bin/plutil -insert HyperMacLocalBuildPath -string "$LOCAL_BUILD_APP_PATH" "${CONTENTS}/Info.plist"
fi

# ── Step 3: Code sign ──
# Dùng chứng chỉ self-signed cố định nếu có (scripts/setup-signing-identity.sh).
# Ký ad-hoc tạo cdhash mới mỗi lần build → macOS thu hồi quyền Accessibility
# sau mỗi lần rebuild. Identity cố định giữ nguyên Designated Requirement.
# Không dùng -v: trên runner CI, cert tự ký không được trust nên -v (valid only)
# sẽ báo 0 identity dù vẫn ký được. codesign chỉ cần identity + private key.
if [ "${SIGN_AVAILABLE}" = "true" ]; then
    echo "🔏 Code signing (${SIGN_IDENTITY})..."
    CODESIGN_ARGS=(--force --deep --sign "${SIGN_IDENTITY}" --identifier "com.opensource.hypermac")
    if [[ -n "${SIGN_KEYCHAIN}" ]]; then
        CODESIGN_ARGS+=(--keychain "${SIGN_KEYCHAIN}")
    fi
    codesign "${CODESIGN_ARGS[@]}" "${APP_DIR}"
else
    echo "🔏 CI code signing (ad-hoc; local build đã bị chặn ở bước đầu)..."
    codesign --force --deep --sign - --identifier "com.opensource.hypermac" "${APP_DIR}"
fi
/usr/bin/codesign --verify --deep --strict --verbose=0 "${APP_DIR}"

# ── Step 3.1: Create release zip package ──
echo "📦 Packaging ${BUILD_DIR}/HyperMac.zip for distribution..."
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "${APP_DIR}" "${STAGING_DIR}/HyperMac.zip"

# ── Step 3.2: Create release DMG package ──
echo "📀 Packaging ${BUILD_DIR}/HyperMac.dmg for distribution..."
DMG_TEMP="${STAGING_DIR}/dmg_temp"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_DIR}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"
hdiutil create -volname "HyperMac" -srcfolder "${DMG_TEMP}" -ov -format UDZO "${STAGING_DIR}/HyperMac.dmg" >/dev/null 2>&1 || true
rm -rf "${DMG_TEMP}"

# Chỉ công bố ứng viên cập nhật sau khi build, ký và đóng gói thành công.
if build_app_is_running; then
    echo "❌ HyperMac vừa được mở từ ${FINAL_APP}; giữ nguyên app đang chạy."
    exit 2
fi
PREVIOUS_APP="${STAGING_DIR}/previous-HyperMac.app"
if [ -d "${FINAL_APP}" ]; then
    mv "${FINAL_APP}" "${PREVIOUS_APP}"
fi
if ! mv "${APP_DIR}" "${FINAL_APP}"; then
    if [ -d "${PREVIOUS_APP}" ]; then mv "${PREVIOUS_APP}" "${FINAL_APP}"; fi
    echo "❌ Không thể công bố bản app mới."
    exit 1
fi
mv -f "${STAGING_DIR}/HyperMac.zip" "${BUILD_DIR}/HyperMac.zip"
if [ -f "${STAGING_DIR}/HyperMac.dmg" ]; then
    mv -f "${STAGING_DIR}/HyperMac.dmg" "${BUILD_DIR}/HyperMac.dmg"
    echo "✅ Package created: ${BUILD_DIR}/HyperMac.dmg"
fi
echo "✅ App mới: ${FINAL_APP}"
echo "✅ Package created: ${BUILD_DIR}/HyperMac.zip"
echo "   Mở HyperMac đang chạy và chọn 'Cập nhật từ build local' để áp dụng."
