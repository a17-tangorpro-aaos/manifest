# Android Automotive OS 17 on Google Pixel Tablet (tangorpro)

This repository provides the manifest and build instructions to compile and run Android Automotive OS 17 (Baklava) on the Google Pixel Tablet (`tangorpro`).

The Pixel Tablet is powered by the Google Tensor G2 SoC and ships with standard consumer Android firmware and a prebuilt vendor partition. Running AAOS 17 on this hardware requires adapting the automotive framework to a single tablet display, relocating automotive hardware abstraction layers (VHAL, AudioControl) to `system_ext` to maintain Treble boundaries, and patching the BootControl HAL to prevent A/B boot slot lockouts.

---

## Requirements

### Host Environment
- **Operating System:** Ubuntu 22.04 LTS or 24.04 LTS (x86_64)
- **CPU:** 16+ physical cores recommended
- **RAM:** 32 GB minimum (configure at least 32 GB swap if building with 32 GB RAM)
- **Storage:** 400 GB free space on NVMe storage
- **Packages:**
  ```bash
  sudo apt update
  sudo apt install -y git-core gnupg flex bison build-essential zip curl zlib1g-dev \
      libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev \
      libxml2-utils xsltproc unzip fontconfig python3 python3-pip \
      android-sdk-platform-tools-common e2fsprogs f2fs-tools
  ```
- **Repo tool:** Google's `repo` tool installed in `$PATH`.

### Target Device
- Google Pixel Tablet (`tangorpro`)
- Unlocked bootloader (`fastboot flashing unlock`)
- Baseline factory firmware: Android 15.0.0 (`BP1A.250505.005`)
- High-quality USB-C cable connected directly to a rear motherboard port (avoid USB hubs)

---

## Flashing Prebuilt Images

Tested prebuilt images are available on GitHub Releases:
- **Release:** [AAOS 17 Baklava Release v1.0](https://github.com/a17-tangorpro-aaos/manifest/releases/tag/v17.0-baklava-v1.0)
- **Archive:** `aaos17_pixel_tablet_tangorpro_v1.0.zip` (1.4 GB)

### Method A: Automated Flashing
Put the tablet into Fastboot mode by holding **Power + Volume Down** from a powered-off state. Extract the archive and execute the flash script:

```bash
# Linux / macOS:
chmod +x flash-all.sh
./flash-all.sh

# Windows:
flash-all.bat
```

The script verifies device unlock status, flashes partitions with `--disable-verity --disable-verification`, writes `super.img`, formats userdata, reboots, and configures landscape orientation and input handling over ADB.

### Method B: Manual Fastboot Flashing
Standalone release archives bundle the dynamic partitions into `super.img` rather than supplying uncompressed image files. Flash partitions explicitly rather than using `fastboot flashall`:

```bash
fastboot flash boot boot.img
fastboot flash init_boot init_boot.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash vendor_kernel_boot vendor_kernel_boot.img
fastboot flash dtbo dtbo.img
fastboot flash pvmfw pvmfw.img
fastboot flash --disable-verity --disable-verification vbmeta vbmeta.img
fastboot flash --disable-verity --disable-verification vbmeta_system vbmeta_system.img
fastboot flash --disable-verity --disable-verification vbmeta_vendor vbmeta_vendor.img
fastboot flash super super.img
fastboot -w reboot
```

### First-Boot Provisioning
First boot takes approximately 60–90 seconds while runtime caches initialize. Once the device boots, run these ADB commands to configure display rotation and disable rotary controller touch interception:

```bash
adb wait-for-device
# Force physical landscape display orientation (270 degrees)
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 3

# Disable rotary controller to prevent touch focus locks on capacitive screens
adb shell pm disable-user --user 0 com.android.car.rotary
adb shell pm disable-user --user 10 com.android.car.rotary

# Disable stub home launcher and show Car Launcher
adb shell pm disable-user --user 10 com.android.car.stub.launcher
adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

---

## Source Code Setup

### 1. Initialize and Sync Workspace
```bash
mkdir -p ~/aaos_on_pixel
cd ~/aaos_on_pixel

repo init -u https://github.com/a17-tangorpro-aaos/manifest -b android-17.0.0_r1-tangorpro
repo sync -c -j$(nproc)
```

### 2. Extract Proprietary Vendor Binaries
The Pixel Tablet requires Tensor G2 drivers from Google:
- **Build ID:** Android 15.0.0 (`BP1A.250505.005`)
- **Download Link:** [Google Drivers for Pixel Devices](https://developers.google.com/android/drivers#tangorpro)

Extract the archive at the root of the AOSP workspace and run the extraction script:
```bash
tar -xvf google_devices-tangorpro-bp1a.250505.005-*.tgz
./extract-google_devices-tangorpro.sh
```
Accept the license agreement. This populates `vendor/google_devices/tangorpro/`.

---

## Repository Structure & Modifications

The manifest replaces upstream repositories with adapted forks from [`a17-tangorpro-aaos`](https://github.com/a17-tangorpro-aaos):

| Repository | Path in Tree | Branch | Description & Key Changes |
| :--- | :--- | :--- | :--- |
| `manifest` | `manifest/` | `android-17.0.0_r1-tangorpro` | Manifest definitions chaining upstream AOSP with tangorpro overlays. |
| `packages_apps_Car_Settings` | `packages/apps/Car/Settings` | `android-17.0.0_r1-tangorpro` | Automotive settings adapted for tablet screens and Wi-Fi/BT navigation. |
| `packages_services_Car` | `packages/services/Car` | `android-17.0.0_r1-tangorpro` | `CarUpdatableDewdRRO` overlay (single task stack, default `CarLauncher`). |
| `device_google_car` | `device/google_car` | `android-17.0.0_r1-tangorpro` | Clean automotive base product definitions with proprietary dependencies removed. |
| `hardware_interfaces` | `hardware/interfaces` | `android-17.0.0_r1-tangorpro` | Relocated Vehicle HAL (VHAL) & AudioControl HAL to `system_ext` (`type="framework"`). |
| `build_release` | `build/release` | `android-17.0.0_r1-tangorpro` | Release flag configuration for Android 17 trunk staging. |
| `build_soong` | `build/soong` | `android-17.0.0_r1-tangorpro` | Soong build modifications for automotive targets. |
| `external_skia` | `external/skia` | `android-17.0.0_r1-tangorpro` | Skia 2D graphics rendering build configuration. |
| `system_core` | `system/core` | `android-17.0.0_r1-tangorpro` | Removed incompatible `rust_static_std` defaults in debuggerd. |
| `system_extras` | `system/extras` | `android-17.0.0_r1-tangorpro` | Fixed Rust linking dependencies in simpleperf. |
| `system_unwinding` | `system/unwinding` | `android-17.0.0_r1-tangorpro` | Fixed Rust linking dependencies in libunwindstack. |
| `device_google_tangorpro` | `device/google/tangorpro` | `android-17.0.0_r1-tangorpro` | `aosp_tangorpro_car.mk`, touchscreen IDC rules, audio routing, display configs. |
| `device_google_gs201` | `device/google/gs201` | `android-17.0.0_r1-tangorpro` | Tensor G2 platform definitions and kernel cmdline (`panic=0`). |
| `device_google_gs-common` | `device/google/gs-common` | `android-17.0.0_r1-tangorpro` | Patched BootControl HAL (AIDL & HIDL) for slot safety (anti-EDL lockout). |
| `device_google_gs201-sepolicy` | `device/google/gs201-sepolicy` | `android-17.0.0_r1-tangorpro` | SELinux policies for automotive services in `system_ext`. |
| `device_google_gs101` | `device/google/gs101` | `android-17.0.0_r1-tangorpro` | Tensor base definitions and display compositor interfaces. |
| `hardware_google_pixel` | `hardware/google/pixel` | `android-17.0.0_r1-tangorpro` | Pixel hardware abstraction interfaces. |
| `hardware_google_graphics_common` | `hardware/google/graphics/common` | `android-17.0.0_r1-tangorpro` | Buffer allocation and common graphics interfaces. |
| `hardware_google_graphics_gs101` | `hardware/google/graphics/gs101` | `android-17.0.0_r1-tangorpro` | Exynos HWC compositor (`libhwc2.1`) enabling 60fps hardware acceleration. |
| `hardware_google_graphics_gs201` | `hardware/google/graphics/gs201` | `android-17.0.0_r1-tangorpro` | Gralloc and hardware composer bindings for Tensor G2. |

---

## Technical Architecture

### 1. BootControl HAL Slot Safety & Prebuilt Vendor Injection
The Pixel bootloader (ABL) records boot attempt counts in `devinfo`. If an unhandled crash or freeze occurs across consecutive boots, ABL decrements `retry_count`. When both slots reach `retry_count = 0`, the device enters Exynos emergency download (EDL) mode (`18d1:4f00`).

To ensure safe recovery during development, `device/google/gs-common/bootctrl/aidl/BootControl.cpp` patches the constructor to reset both slots on every boot:
```cpp
// Patched in BootControl::BootControl():
reset_boot_slots_to_safe_defaults(); // sets unbootable=0, retry_count=3, successful=1
```

#### Why BootControl Requires Vendor Injection vs. system_ext Relocation
A common question in Treble bring-up is: *Why inject BootControl into `vendor.img` while relocating other automotive HALs to `system_ext`?*

1. **Early Boot Execution Timing (`class early_hal`):**  
   BootControl is invoked by `init` during early initialization (`class early_hal`) before dynamic partitions like `/system_ext` are mounted. Moving BootControl to `/system_ext` would cause `init` to fail before storage partitions can be mounted.
2. **Pre-existing Vendor VINTF & Init Definition:**  
   Google's prebuilt `vendor.img` already defines `/vendor/bin/hw/android.hardware.boot-service.default-pixel` in its init `.rc` files and `/vendor/etc/vintf/manifest.xml`. Replacing the binary directly in `vendor.img` preserves the existing vendor VINTF contract and SELinux domain without requiring vendor policy changes.

Because Google's driver package provides `vendor.img` as an existing filesystem (`vendor/google_devices/tangorpro/proprietary/vendor.img`), running `m superimage` packages Google's stock vendor image rather than the newly built binary from `out/target/product/tangorpro/vendor/bin/hw/`.

To ensure the patched HAL is included in `super.img`, inject the compiled binary into the vendor image using `debugfs`:

```bash
# 1. Build the BootControl HAL binary
m android.hardware.boot-service.default-pixel -j$(nproc)

# 2. Inject into the proprietary vendor image with proper permissions and SELinux label
TARGET_HAL="out/target/product/tangorpro/vendor/bin/hw/android.hardware.boot-service.default-pixel"
VENDOR_IMG="vendor/google_devices/tangorpro/proprietary/vendor.img"

debugfs -w "$VENDOR_IMG" << 'EOF'
rm /bin/hw/android.hardware.boot-service.default-pixel
write out/target/product/tangorpro/vendor/bin/hw/android.hardware.boot-service.default-pixel /bin/hw/android.hardware.boot-service.default-pixel
sif /bin/hw/android.hardware.boot-service.default-pixel mode 0100755
sif /bin/hw/android.hardware.boot-service.default-pixel uid 0
sif /bin/hw/android.hardware.boot-service.default-pixel gid 2000
ea_set /bin/hw/android.hardware.boot-service.default-pixel security.selinux u:object_r:hal_bootctl_default_exec:s0
EOF

# 3. Apply the same update to the staged build image if present
if [ -f "out/target/product/tangorpro/vendor.img" ]; then
debugfs -w out/target/product/tangorpro/vendor.img << 'EOF'
rm /bin/hw/android.hardware.boot-service.default-pixel
write out/target/product/tangorpro/vendor/bin/hw/android.hardware.boot-service.default-pixel /bin/hw/android.hardware.boot-service.default-pixel
sif /bin/hw/android.hardware.boot-service.default-pixel mode 0100755
sif /bin/hw/android.hardware.boot-service.default-pixel uid 0
sif /bin/hw/android.hardware.boot-service.default-pixel gid 2000
ea_set /bin/hw/android.hardware.boot-service.default-pixel security.selinux u:object_r:hal_bootctl_default_exec:s0
EOF
fi

# 4. Pack the final dynamic super partition
m superimage -j$(nproc)
```

**Verification:**
After booting, check kernel log:
```bash
adb shell dmesg | grep bootcontrolhal
```
Expected output:
```text
bootcontrolhal: BootControl safety patch (AIDL): forcing slots to be bootable and successful
```
In fastboot mode, verify that retry counters are preserved:
```bash
fastboot getvar all 2>&1 | grep -E "slot-retry-count|slot-successful"
# Expected: slot-retry-count:a:3, slot-retry-count:b:3, slot-successful:a:yes, slot-successful:b:yes
```

### 2. Hardware Compositing (libhwc2.1)
Default automotive generic builds fall back to software rendering (`swiftshader`), limiting UI frame rates to 5–10 fps. We adapted `hardware/google/graphics/gs101` to compile `libhwc2.1`, linking directly with Mali GPU and Exynos Display Processor (DPU) drivers for full 60fps hardware-accelerated rendering.

### 3. Touch Digitizer Mapping (.idc)
Consumer tablets report touch events differently than fixed automotive in-dash head units. We added `device/google/tangorpro/NVTCapacitiveTouchScreen.idc`:
```properties
touch.deviceType = touchScreen
touch.orientationAware = 1
```
This aligns touch coordinates and USI active stylus tracking with the 2560x1600 physical display in landscape orientation.

### 4. Automotive Treble HALs in system_ext (Framework HAL Architecture)
Standard automotive platforms host the Vehicle HAL (VHAL) and AudioControl HAL in `/vendor`. However, on consumer hardware like the Pixel Tablet:
1. **No Existing Vendor Definitions:** The stock vendor image contains no automotive VINTF entries, init scripts, or automotive SELinux type definitions.
2. **Treble Integrity:** Modifying the prebuilt vendor partition's compiled SELinux policy (`vendor_sepolicy.cil`) and VINTF manifests is fragile and breaks Treble isolation.

Following official Android Treble design for platform extensions (the same pattern used by Automotive GSI and Cuttlefish), automotive domain HALs are hosted in `system_ext` as **Framework HALs**:
- **Vehicle HAL (VHAL):** Built as `android.hardware.automotive.vehicle@V3-default-service` in `system_ext` (`system_ext_specific: true`) with `type="framework"` in its VINTF manifest.
- **AudioControl HAL:** Relocated to `system_ext` with dynamic multizone routing enabled.

This cleanly separates device-specific hardware drivers (which remain untouched in the vendor partition) from automotive domain logic (managed in the framework-extensible `system_ext` partition).

### 5. Automotive Windowing & Car Launcher
In `packages/services/Car/car_product/dewd/rro/CarUpdatableDewdRRO/res/values/config.xml`:
- `config_isUsingAutoTaskStackWindowing` is set to `false`. Multi-display vehicle window managers expect external instrument clusters and crash on single-panel tablets.
- `config_driverHomeComponent` is set to `com.android.car.carlauncher/.CarLauncher`.

### 6. Crash Loop Protection
`panic=0` is added to `BOARD_KERNEL_CMDLINE` in `device/google/gs201/BoardConfig.mk`. If an unhandled kernel panic occurs during driver bring-up, the system freezes safely instead of repeatedly rebooting and exhausting bootloader retry counts.

---

## Compilation and Flashing

### 1. Build from Source
```bash
cd ~/aaos_on_pixel
source build/envsetup.sh
lunch aosp_tangorpro_car-trunk_staging-userdebug

# Build the complete tree
m -j$(nproc)

# Inject the BootControl HAL into vendor.img (refer to the debugfs steps above), then:
m superimage -j$(nproc)
```

### 2. Flashing the Source Build

#### Option A: Automated Script
Use the root flashing script:
```bash
./flash_all_manual.sh
```

#### Option B: Fastboot Command Line
```bash
adb reboot bootloader
ANDROID_PRODUCT_OUT=out/target/product/tangorpro fastboot flashall -w --disable-verity --disable-verification
```

---

## Subsystem Status

| Subsystem | Status | Technical Details |
| :--- | :--- | :--- |
| Graphics & Display | Working | 60fps hardware-accelerated rendering via `libhwc2.1` Exynos HWC. |
| Touchscreen & Stylus | Working | Landscape digitizer coordinate mapping via `NVTCapacitiveTouchScreen.idc`. |
| Wi-Fi (802.11ax) | Working | Functional via Tensor G2 Wi-Fi HAL. |
| Bluetooth 5.2 | Working | Functional for audio streaming and input devices. |
| Audio Routing | Working | Multizone `CarAudioService` with Dynamic Audio Routing. |
| Vehicle HAL (VHAL) | Working | AIDL Mock VHAL running in `system_ext` with `CarSettings` support. |
| Boot & Slot Safety | Working | BootControl HAL slot safety (`retry_count = 3`, `successful = 1`). |

---

## Recovery & Diagnostics

### Fastboot Slot Inspection and Manual Recovery
To inspect or reset the active boot slot in Fastboot:

```bash
# Query active slot and retry counts
fastboot getvar all 2>&1 | grep -E "current-slot|slot-retry-count|slot-successful"

# Set slot A active
fastboot set_active a

# Reboot
fastboot reboot
```

---

## Reverting to Stock Android 15

To return the Pixel Tablet from AAOS 17 back to standard consumer Android 15, use either Google's web-based Android Flash Tool or the official factory image package.

### Option A: Android Flash Tool (Web Browser)
The Android Flash Tool runs directly in Chromium-based browsers (Chrome, Brave, Chromium) using WebUSB.

1. Connect the tablet to your PC and boot into Fastboot mode (**Power + Volume Down**).
2. Open [flash.android.com](https://flash.android.com) in your browser.
3. Select **Add new device** and choose the Pixel Tablet (`tangorpro`).
4. Select the target build: **Android 15.0.0 (`BP1A.250505.005`)** or the latest stable release.
5. In the flash configuration, enable **Wipe Device** and **Force Flash All Partitions**.
6. Click **Install build** and keep the device connected until the process completes.

### Option B: Fastboot Factory Image Package
1. Download the official factory image for the Pixel Tablet (`tangorpro`):
   - [Google Pixel Factory Images](https://developers.google.com/android/images#tangorpro)
   - Target build: `BP1A.250505.005` (or newer).
2. Extract the archive:
   ```bash
   unzip tangorpro-bp1a.250505.005-factory-*.zip
   cd tangorpro-bp1a.250505.005
   ```
3. Put the device into Fastboot mode and run the factory flasher:
   ```bash
   # Linux / macOS:
   ./flash-all.sh

   # Windows:
   flash-all.bat
   ```
   This reflashes all stock factory partitions, restores stock AVB metadata signatures, and formats `userdata`.

> **Warning regarding Bootloader Locking:**  
> Do not attempt to re-lock the bootloader (`fastboot flashing lock`) while custom partitions or disabled AVB verification flags are active. Only re-lock the bootloader after stock factory images have been flashed and the device has completed a full, successful boot into stock Android.

