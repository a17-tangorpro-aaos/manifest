# Comprehensive Guide: Android 17 (AAOS) Bring-up on Pixel Tablet (tangorpro)

This unified guide provides a complete, production-ready walkthrough to test, modify, compile, and flash **Android Automotive OS (AAOS) 17 (Baklava)** onto a **Google Pixel Tablet (`tangorpro`)**.

Because the Pixel Tablet is natively a standard consumer tablet with a locked, prebuilt vendor partition, bringing up Automotive OS requires adapting the Automotive framework, relocating automotive HALs to `system_ext`, and safeguarding boot slots. This guide documents every architecture decision, repository modification, and flashing command required for any developer to reproduce the bring-up from scratch.

---

## 📋 System & Hardware Prerequisites

### 1. Host Build Machine
* **Operating System:** Ubuntu 22.04 LTS or Ubuntu 24.04 LTS (x86_64).
* **CPU:** 16+ physical cores recommended (e.g., AMD Ryzen 9 / Intel Core i9 / Xeon).
* **Memory (RAM):** 32 GB minimum (64 GB recommended; configure at least 32 GB swap if using 32 GB RAM).
* **Disk Space:** At least **400 GB** of free space on a high-speed NVMe SSD (AOSP checkout + build artifacts).
* **Required Build Packages:**
  ```bash
  sudo apt update
  sudo apt install -y git-core gnupg flex bison build-essential zip curl zlib1g-dev \
      libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev \
      libxml2-utils xsltproc unzip fontconfig python3 python3-pip android-sdk-platform-tools-common \
      e2fsprogs f2fs-tools
  ```
* **Google Repo Tool:** Ensure `repo` is installed in `~/bin` or `/usr/local/bin` and added to `$PATH`.

### 2. Target Device
* **Device:** Google Pixel Tablet (`tangorpro`).
* **Baseline Firmware:** Stock Android 15.0.0 factory build matching the vendor drivers (**`BP1A.250505.005`**).
* **Bootloader State:** Unlocked (`fastboot flashing unlock`).
* **Connection:** High-quality USB-C to USB-C or USB-A cable connected directly to a rear motherboard USB 3.0+ port (avoid USB hubs).

---

## Phase 0: Quick Start (Prebuilt Image Download & 1-Click Flashing)

If you want to run and evaluate AAOS 17 on your Pixel Tablet immediately without compiling AOSP from source:

### 1. Download Prebuilt Package
* **Release Asset:** [Download AAOS 17 Baklava Release Zip v1.0](https://github.com/a17-tangorpro-aaos/manifest/releases/tag/v17.0-baklava-v1.0)
* **File Name:** `aaos17_pixel_tablet_tangorpro_v1.0.zip` (1.4 GB)
* **Included Files:**
  * `boot.img`, `init_boot.img`, `vendor_boot.img`, `vendor_kernel_boot.img`
  * `dtbo.img`, `pvmfw.img`
  * `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img`
  * `super.img` (contains patched `system`, `system_ext`, `product`, and `vendor`)
  * `flash-all.sh` (Linux/macOS automated flasher)
  * `flash-all.bat` (Windows automated flasher)

### 2. Flashing Instructions

Put your Pixel Tablet into Fastboot mode by powering off and holding **Power + Volume Down**.

#### Method A: Automated 1-Click Script (Recommended)
Extract the release zip and execute the flasher:
```bash
# Linux / macOS:
chmod +x flash-all.sh
./flash-all.sh

# Windows:
double-click flash-all.bat
```
The script will wait for device detection, check bootloader unlock state, flash all partitions with verity/verification disabled, wipe userdata, reboot, and automatically configure landscape orientation and input handling via ADB once booted.

#### Method B: Direct Fastboot Commands
> [!NOTE]
> Standalone prebuilt release packages package the dynamic partitions into `super.img` rather than providing loose `system.img` / `product.img` files. Therefore, run explicit partition flash commands instead of `fastboot flashall`:

```bash
# 1. Flash kernel and bootloader support partitions
fastboot flash boot boot.img
fastboot flash init_boot init_boot.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash vendor_kernel_boot vendor_kernel_boot.img
fastboot flash dtbo dtbo.img
fastboot flash pvmfw pvmfw.img

# 2. Flash AVB metadata with verification disabled
fastboot flash --disable-verity --disable-verification vbmeta vbmeta.img
fastboot flash --disable-verity --disable-verification vbmeta_system vbmeta_system.img
fastboot flash --disable-verity --disable-verification vbmeta_vendor vbmeta_vendor.img

# 3. Flash dynamic super partition
fastboot flash super super.img

# 4. Wipe userdata & metadata and reboot
fastboot -w reboot
```

#### First-Boot Post-Provisioning
On the first boot (takes ~60–90 seconds), run the following ADB commands to lock the landscape orientation, prevent rotary focus locks, and show Car Launcher:
```bash
adb wait-for-device
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 3
adb shell pm disable-user --user 0 com.android.car.rotary
adb shell pm disable-user --user 10 com.android.car.rotary
adb shell pm disable-user --user 10 com.android.car.stub.launcher
adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

---

## Phase 1: Source Code Synchronization

### 1. Initialize and Sync the Repository
Initialize the workspace using our unified manifest repository:

```bash
mkdir -p ~/aaos_on_pixel
cd ~/aaos_on_pixel

# Initialize repository using our custom manifest
repo init -u https://github.com/a17-tangorpro-aaos/manifest -b android-17.0.0_r1-tangorpro

# Sync all source repositories (shallow clone for performance)
repo sync -c -j$(nproc)
```

### 2. Download and Extract Proprietary Vendor Binaries
The Pixel Tablet requires Tensor G2 proprietary binaries from Google:

* **Official Driver Page:** [Google Drivers for Pixel Devices (`tangorpro`)](https://developers.google.com/android/drivers#tangorpro)
* **Required Build ID:** **Android 15.0.0 (`BP1A.250505.005`)**

**Extraction Steps:**
1. Download `google_devices-tangorpro-bp1a.250505.005-*.tgz`.
2. Extract the archive at the root of the AOSP workspace:
   ```bash
   tar -xvf google_devices-tangorpro-bp1a.250505.005-*.tgz
   ```
3. Run the extraction script and accept the license terms:
   ```bash
   ./extract-google_devices-tangorpro.sh
   ```
   This populates the proprietary prebuilt tree at `vendor/google_devices/tangorpro/`.

---

## Phase 2: Architecture & Repository Modifications

Our custom manifest replaces standard AOSP repositories with modified forks under the [`a17-tangorpro-aaos`](https://github.com/a17-tangorpro-aaos) organization.

### Complete Manifest Repositories Reference

| Repository Name | Path in Source Tree | Branch | Purpose & Key Modifications |
| :--- | :--- | :--- | :--- |
| **`manifest`** | `manifest/` | `android-17.0.0_r1-tangorpro` | Custom manifest definition chaining upstream AOSP with tangorpro overlays. |
| **`packages_apps_Car_Settings`** | `packages/apps/Car/Settings` | `android-17.0.0_r1-tangorpro` | Automotive settings adapted for tablet display and standard Wi-Fi/BT submenus. |
| **`packages_services_Car`** | `packages/services/Car` | `android-17.0.0_r1-tangorpro` | `CarUpdatableDewdRRO` overlay (single task stack, default `CarLauncher`). |
| **`device_google_car`** | `device/google_car` | `android-17.0.0_r1-tangorpro` | Clean automotive base product definitions (removed proprietary GMS ties). |
| **`hardware_interfaces`** | `hardware/interfaces` | `android-17.0.0_r1-tangorpro` | Relocated Vehicle HAL (VHAL) & AudioControl HAL to `system_ext` (`type="framework"`). |
| **`build_release`** | `build/release` | `android-17.0.0_r1-tangorpro` | Release configuration flags for Android 17 trunk staging. |
| **`build_soong`** | `build/soong` | `android-17.0.0_r1-tangorpro` | Soong build system adjustments for automotive build targets. |
| **`external_skia`** | `external/skia` | `android-17.0.0_r1-tangorpro` | Skia 2D graphics rendering optimizations. |
| **`system_core`** | `system/core` | `android-17.0.0_r1-tangorpro` | Removed incompatible `rust_static_std` defaults in debuggerd. |
| **`system_extras`** | `system/extras` | `android-17.0.0_r1-tangorpro` | Fixed Rust linking dependencies in simpleperf. |
| **`system_unwinding`** | `system/unwinding` | `android-17.0.0_r1-tangorpro` | Fixed Rust linking dependencies in libunwindstack. |
| **`device_google_tangorpro`** | `device/google/tangorpro` | `android-17.0.0_r1-tangorpro` | `aosp_tangorpro_car.mk`, touchscreen IDC rules, audio routing, display configs. |
| **`device_google_gs201`** | `device/google/gs201` | `android-17.0.0_r1-tangorpro` | Tensor G2 platform definitions, kernel command-line arguments (`panic=0`). |
| **`device_google_gs-common`** | `device/google/gs-common` | `android-17.0.0_r1-tangorpro` | Patched BootControl HAL (AIDL & HIDL) for slot safety (anti-EDL brick protection). |
| **`device_google_gs201-sepolicy`** | `device/google/gs201-sepolicy` | `android-17.0.0_r1-tangorpro` | SELinux policies for automotive HALs running in `system_ext`. |
| **`device_google_gs101`** | `device/google/gs101` | `android-17.0.0_r1-tangorpro` | Tensor baseline definitions and display compositor interfaces. |
| **`hardware_google_pixel`** | `hardware/google/pixel` | `android-17.0.0_r1-tangorpro` | Pixel hardware abstraction interfaces. |
| **`hardware_google_graphics_common`** | `hardware/google/graphics/common` | `android-17.0.0_r1-tangorpro` | Common graphics allocation and buffer management. |
| **`hardware_google_graphics_gs101`** | `hardware/google/graphics/gs101` | `android-17.0.0_r1-tangorpro` | Exynos HWC compositor (`libhwc2.1`) enabling full 60fps hardware acceleration. |
| **`hardware_google_graphics_gs201`** | `hardware/google/graphics/gs201` | `android-17.0.0_r1-tangorpro` | Gralloc and hardware composer bindings for Tensor G2. |

---

### Core Architecture Highlights

#### 1. BootControl HAL Slot Safety & Prebuilt Vendor Injection
The Pixel bootloader (ABL) tracks boot attempts using retry counters in `devinfo`. If boot fails twice, the bootloader marks the slot unbootable; if both slots become unbootable, the device drops into Exynos EDL mode (`18d1:4f00`).

To guarantee recovery safety, `device/google/gs-common/bootctrl/aidl/BootControl.cpp` is patched to force both slots bootable on startup:
```cpp
// Patched in BootControl constructor:
reset_boot_slots_to_safe_defaults(); // sets unbootable=0, retry_count=3, successful=1
```

> [!IMPORTANT]
> **Prebuilt Vendor Partition Quirk:**  
> The Google proprietary driver package supplies `vendor.img` as an existing prebuilt filesystem (`vendor/google_devices/tangorpro/proprietary/vendor.img`). Because `vendor.img` is prebuilt, standard `m superimage` does not automatically overwrite `/vendor/bin/hw/android.hardware.boot-service.default-pixel` from your build output.  
>  
> For source builds, you must inject the compiled binary into `vendor.img` using `debugfs` before generating `super.img`:

```bash
# 1. Compile the BootControl HAL binary
m android.hardware.boot-service.default-pixel -j$(nproc)

# 2. Inject into the proprietary prebuilt vendor image
TARGET_HAL="out/target/product/tangorpro/vendor/bin/hw/android.hardware.boot-service.default-pixel"
VENDOR_IMG="vendor/google_devices/tangorpro/proprietary/vendor.img"

debugfs -w -R "rm bin/hw/android.hardware.boot-service.default-pixel" "$VENDOR_IMG"
debugfs -w -R "write $TARGET_HAL bin/hw/android.hardware.boot-service.default-pixel" "$VENDOR_IMG"
debugfs -w -R "sif bin/hw/android.hardware.boot-service.default-pixel mode 0755" "$VENDOR_IMG"

# Also update the staged build vendor image:
debugfs -w -R "rm bin/hw/android.hardware.boot-service.default-pixel" out/target/product/tangorpro/vendor.img
debugfs -w -R "write $TARGET_HAL bin/hw/android.hardware.boot-service.default-pixel" out/target/product/tangorpro/vendor.img
debugfs -w -R "sif bin/hw/android.hardware.boot-service.default-pixel mode 0755" out/target/product/tangorpro/vendor.img

# 3. Regenerate super.img with the patched vendor image
m superimage -j$(nproc)
```
*Verification:* Run `adb shell dmesg | grep bootcontrolhal` on device to confirm:
`bootcontrolhal: BootControl safety patch (AIDL): forcing slots to be bootable and successful`

#### 2. 60fps Hardware Accelerated Compositing (`libhwc2.1`)
Standard Android 17 generic automotive builds default to software rendering (`swiftshader`), causing severe UI lag (~5-10 fps). We adapted `hardware/google/graphics/gs101` to compile `libhwc2.1`, linking directly with Mali GPU and Exynos Display Processor (DPU) drivers to unlock full **60fps hardware-accelerated rendering**.

#### 3. Touchscreen Digitizer Calibration (`.idc`)
Landscape tablet digitizers map touch coordinates differently than portrait car displays. We injected `NVTCapacitiveTouchScreen.idc` in `device/google/tangorpro`:
```properties
touch.deviceType = touchScreen
touch.orientationAware = 1
```

#### 4. Automotive Treble Migration to `system_ext`
Because `vendor.img` cannot be completely rebuilt from source without proprietary SoC source trees, automotive HALs are relocated to `system_ext`:
* **Vehicle HAL (VHAL):** Built into `system_ext/bin/hw/android.hardware.automotive.vehicle@V3-default-service` with `type="framework"` in its VINTF manifest.
* **AudioControl HAL:** Relocated to `system_ext` with dynamic multizone routing.

#### 5. Automotive Windowing & Default Car Launcher
In `packages/services/Car/car_product/dewd/rro/CarUpdatableDewdRRO/res/values/config.xml`:
* Disabled `config_isUsingAutoTaskStackWindowing` (`false`) to eliminate multi-display windowing crash loops on single-screen tablets.
* Bound `config_driverHomeComponent` to `com.android.car.carlauncher/.CarLauncher`.

#### 6. Crash Loop Protection
Added `panic=0` to `BOARD_KERNEL_CMDLINE` in `device/google/gs201/BoardConfig.mk`. If an unhandled kernel error occurs during driver development, the kernel freezes rather than endlessly rebooting into EDL mode.

---

## Phase 3: Compilation and Flashing

### 1. Set Up Environment & Compile
```bash
cd ~/aaos_on_pixel
source build/envsetup.sh
lunch aosp_tangorpro_car-trunk_staging-userdebug

# Build the complete system
m -j$(nproc)

# Ensure BootControl HAL is injected into vendor.img (see Phase 2 instructions)
# and build final super image:
m superimage -j$(nproc)
```

### 2. Flashing the Source Build

#### Option A: Using the Automated Script
We provide a root-level flashing script [`flash_all_manual.sh`](file:///mnt/hemang/aaos_on_pixel/flash_all_manual.sh):
```bash
# Connect tablet in Fastboot mode (Power + Volume Down)
./flash_all_manual.sh
```

#### Option B: Standard Fastboot Command Line
```bash
# Reboot into Fastboot mode
adb reboot bootloader

# Flash all partitions built from source
ANDROID_PRODUCT_OUT=out/target/product/tangorpro fastboot flashall -w --disable-verity --disable-verification
```

---

## ✅ Working Hardware & Subsystems Status Matrix

| Subsystem | Status | Technical Details |
| :--- | :--- | :--- |
| 🎨 **Graphics & Display** | 🟢 **Working** | Full 60fps Hardware-Accelerated UI via `libhwc2.1` Exynos HWC. |
| 📱 **Touchscreen & Stylus** | 🟢 **Working** | Accurate landscape digitizer mapping via `NVTCapacitiveTouchScreen.idc`. |
| 📶 **Wi-Fi (802.11ax)** | 🟢 **Working** | Functional via Tensor G2 Wi-Fi HAL. |
| 🔷 **Bluetooth 5.2** | 🟢 **Working** | Functional Bluetooth stack for media and telephony. |
| 🔊 **Audio & Routing** | 🟢 **Working** | Multizone `CarAudioService` with Dynamic Audio Routing enabled. |
| 🚗 **Automotive VHAL** | 🟢 **Working** | Mock AIDL VHAL running in `system_ext` with `CarSettings` support. |
| 🛡️ **Boot & Slot Safety** | 🟢 **Working** | BootControl HAL slot safety (`retry_count = 3`, `successful = 1`). |

---

## Phase 4: Device Recovery & Management

### Slot Inspection and Manual Recovery
If you need to verify or reset the A/B slot status in Fastboot:

```bash
# Check slot status and retry counts
fastboot getvar all 2>&1 | grep -E "current-slot|slot-retry-count|slot-successful"

# Manually set slot A active
fastboot set_active a

# Reboot device
fastboot reboot
```
