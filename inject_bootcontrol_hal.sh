#!/usr/bin/env bash
# ==============================================================================
# Inject Safety-Patched BootControl HAL into Prebuilt vendor.img & Rebuild super
# Target: Google Pixel Tablet (tangorpro) - Android Automotive OS 17 (Baklava)
# ==============================================================================
set -e

# Automatically locate AOSP root directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AOSP_ROOT="$CURRENT_DIR"
while [ "$AOSP_ROOT" != "/" ] && [ ! -f "$AOSP_ROOT/build/envsetup.sh" ]; do
    AOSP_ROOT="$(dirname "$AOSP_ROOT")"
done

if [ ! -f "$AOSP_ROOT/build/envsetup.sh" ]; then
    echo "[-] Error: Could not locate AOSP root directory (build/envsetup.sh not found)."
    exit 1
fi

cd "$AOSP_ROOT"

echo "=================================================================="
echo "AAOS 17 Tangorpro - BootControl HAL Vendor Injection"
echo "=================================================================="

# 1. Check for debugfs
if ! command -v debugfs >/dev/null 2>&1; then
    echo "[-] Error: 'debugfs' tool not found. Please install e2fsprogs:"
    echo "    sudo apt update && sudo apt install -y e2fsprogs"
    exit 1
fi

TARGET_HAL="$AOSP_ROOT/out/target/product/tangorpro/vendor/bin/hw/android.hardware.boot-service.default-pixel"
PROPRIETARY_VENDOR="$AOSP_ROOT/vendor/google_devices/tangorpro/proprietary/vendor.img"
STAGED_VENDOR="$AOSP_ROOT/out/target/product/tangorpro/vendor.img"

# 2. Verify or build BootControl HAL
if [ ! -f "$TARGET_HAL" ]; then
    echo "[*] Compiled BootControl HAL not found. Compiling target now..."
    source build/envsetup.sh
    lunch aosp_tangorpro_car-trunk_staging-userdebug
    m android.hardware.boot-service.default-pixel -j$(nproc)
fi

if [ ! -f "$TARGET_HAL" ]; then
    echo "[-] Error: Failed to find or compile $TARGET_HAL"
    exit 1
fi

inject_hal() {
    local img="$1"
    echo "[+] Injecting BootControl HAL into: $img"
    debugfs -w "$img" << EOF
rm /bin/hw/android.hardware.boot-service.default-pixel
write $TARGET_HAL /bin/hw/android.hardware.boot-service.default-pixel
sif /bin/hw/android.hardware.boot-service.default-pixel mode 0100755
sif /bin/hw/android.hardware.boot-service.default-pixel uid 0
sif /bin/hw/android.hardware.boot-service.default-pixel gid 2000
ea_set /bin/hw/android.hardware.boot-service.default-pixel security.selinux u:object_r:hal_bootctl_default_exec:s0
EOF
}

# 3. Inject into proprietary vendor image
if [ -f "$PROPRIETARY_VENDOR" ]; then
    inject_hal "$PROPRIETARY_VENDOR"
else
    echo "[-] Warning: $PROPRIETARY_VENDOR not found."
fi

# 4. Inject into staged build vendor image if present
if [ -f "$STAGED_VENDOR" ]; then
    inject_hal "$STAGED_VENDOR"
fi

# 5. Rebuild super.img with the updated vendor filesystem
echo "[+] Rebuilding dynamic super.img..."
source build/envsetup.sh
lunch aosp_tangorpro_car-trunk_staging-userdebug
m superimage -j$(nproc)

echo "=================================================================="
echo "✅ BootControl HAL successfully injected and super.img rebuilt!"
echo "   Output: out/target/product/tangorpro/super.img"
echo "=================================================================="
