# Comprehensive Guide: Android 17 (AAOS) Bring-up on Pixel Tablet (tangorpro)

This unified guide provides a complete, step-by-step walkthrough to test, modify, compile, and flash Android Automotive OS (AAOS) 17 onto a Google Pixel Tablet (`tangorpro`).

Because the Pixel Tablet is originally a standard Android tablet with a locked, prebuilt vendor partition, we must adapt the Automotive framework and inject the required Automotive HALs into the `system_ext` partition. This guide details every source code modification required across all AOSP repositories to make this work.

---

## Phase 0: Quick Start (Prebuilt Image Download & 1-Click Flashing)

If you want to test AAOS 17 on your Pixel Tablet immediately without building AOSP from source:

### 1. Download Prebuilt Package
* **Release Zip:** [Download AAOS 17 Baklava Release Zip v1.0](https://github.com/a17-tangorpro-aaos/manifest/releases/tag/v17.0-baklava-v1.0)
* **File Name:** `aaos17_pixel_tablet_tangorpro_v1.0.zip` (1.4 GB)
* **Contents:** `boot.img`, `super.img`, `vbmeta.img`, `vbmeta_system.img`, `vbmeta_vendor.img`, `flash-all.sh`, `flash-all.bat`.

### 2. Flashing Instructions (Quick & Safe)
Ensure your tablet's bootloader is unlocked (`fastboot flashing unlock`) and on an Android 15 bootloader base. Connect your tablet in Fastboot mode (**Power + Vol Down**).

* **Method A (1-Click Script):**  
  Unzip the package and run the included script:
  ```bash
  # On Linux / macOS:
  ./flash-all.sh

  # On Windows:
  double-click flash-all.bat
  ```

* **Method B (Manual Fastboot):**
  ```bash
  fastboot --disable-verity --disable-verification flashall -w
  fastboot reboot
  ```

*Note: The automated scripts (`flash-all.sh` / `flash-all.bat`) apply landscape display orientation and capacitive touch optimizations automatically. If setting up manually, run:*
```bash
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 3
adb shell pm disable-user --user 0 com.android.car.rotary
adb shell pm disable-user --user 10 com.android.car.rotary
adb shell pm disable-user --user 10 com.android.car.stub.launcher
adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

---

## Phase 1: Source Code Synchronization

### 1. Initialize and Sync the Repository (22+ Tracked Repositories)
Download the customized AOSP source tree containing all 22+ tracked repositories and configurations:

```bash
mkdir -p ~/aaos_on_pixel
cd ~/aaos_on_pixel
# Initialize repository using our custom manifest
repo init -u https://github.com/a17-tangorpro-aaos/manifest -b android-17.0.0_r1-tangorpro
# Sync all tracked source repositories
repo sync -c -j$(nproc)
```

### 2. Download and Extract Proprietary Vendor Binaries
The Pixel Tablet requires proprietary hardware drivers to function.

* **Driver Download Page:** [Google Drivers for Pixel Tablet (`tangorpro`)](https://developers.google.com/android/drivers#tangorpro)
* **Required Driver Version:** **Pixel Tablet binaries for Android 15.0.0 (BP1A.250505.005)**

**Extraction Steps:**
1. Download the **Google Drivers** (`extract-google_devices-tangorpro-*.sh`) archive for the **Pixel Tablet (`tangorpro`)**.
2. Extract the `.tgz` archive at the root of your AOSP source tree.
3. Run `extract-google_devices-tangorpro.sh` and accept the license agreement. This populates `vendor/google_devices/tangorpro/` with proprietary binaries.

---

## Phase 2: AOSP Repository Modifications & Highlights

### 1. Kernel Storage Controller Alignment
Integrated proprietary prebuilt Tensor G2 storage controller drivers (UFS physical layer) into our local manifest to prevent boot-time filesystem mount loops on `/data` and `/metadata`.

### 2. 60fps GPU Acceleration (libhwc2.1)
Adapted `hardware/google/graphics/gs101` to build the Exynos hardware compositor (`libhwc2.1`). This bypasses Soong build restrictions on legacy makefiles, bringing full 60fps hardware-accelerated drawing to the UI.

### 3. Touch Digitizer & Stylus Mapping (.idc)
Injected Touch Device Configuration (`.idc`) overrides (`NVTCapacitiveTouchScreen.idc`) to map touch and stylus coordinates accurately in landscape orientation.

### 4. Fix Android 17 Rust Static Linking Errors
Remove `"rust_static_std"` from defaults blocks in:
* `system/core/debuggerd/Android.bp`
* `system/extras/simpleperf/Android.bp`
* `system/unwinding/libunwindstack/Android.bp`

### 5. Migrate Automotive HALs to system_ext (Treble Relocation)
* **Vehicle HAL (VHAL):** Edit `hardware/interfaces/automotive/vehicle/aidl/impl/current/vhal/Android.bp` (`system_ext_specific: true`) and change `vhal-default-service.xml` tag to `type="framework"`.
* **AudioControl HAL:** Edit `hardware/interfaces/automotive/audiocontrol/aidl/default/Android.bp` and `converter/Android.bp` (`system_ext_specific: true`) and change manifest tag to `type="framework"`.

### 6. BootControl HAL Slot Safety (EDL Prevention)
Patched the `BootControl::BootControl()` constructor in `device/google/gs-common/bootctrl/aidl/BootControl.cpp` (and HIDL 1.2 implementation) to automatically reset both slots to `unbootable = 0`, `retry_count = 3`, and `successful = 1` in `devinfo` on every startup. This prevents the Android Bootloader (ABL) from marking active slots unbootable and dropping the device into Exynos EDL mode (`18d1:4f00`) during debugging.
*Note: BootControl HAL is retained in `/vendor/bin/hw/` (`vendor: true`) because `init` starts it as `class early_hal` before `/system_ext` is mounted.*

### 7. Automotive Windowing & Default Car Launcher (`CarUpdatableDewdRRO`)
In `packages/services/Car/car_product/dewd/rro/CarUpdatableDewdRRO/res/values/config.xml`:
* Set `config_isUsingAutoTaskStackWindowing` to `false` (single-screen tablets do not use multi-display automotive task stack windowing, avoiding startup crash loops).
* Set `config_driverHomeComponent` and `config_passengerHomeComponent` to `com.android.car.carlauncher/.CarLauncher` (replacing the placeholder `StubHome`).

### 8. System Server & Crash Loop Protection
* **PackageManager Alignment:** Ensure `PackageManagerService` package installer dependencies are aligned for AOSP Car Launcher to guarantee clean, stable `system_server` startup without crash loops.
* **Kernel panic=0:** Add `panic=0` to `BOARD_KERNEL_CMDLINE` in `BoardConfig.mk` so driver crashes freeze safely instead of auto-rebooting 7 times into EDL mode (`18d1:4f00`).

---

## Phase 3: Compilation and Flashing

### 1. Build the Source
Initialize the build environment and compile the Automotive OS target.

```bash
cd ~/aaos_on_pixel
source build/envsetup.sh
lunch aosp_tangorpro_car-trunk_staging-userdebug
m -j$(nproc)
```

### 2. Safe Flashing Protocol
Reboot your Pixel Tablet into the bootloader (Fastboot mode) by holding **Power + Volume Down**.

```bash
# 1. Connect tablet in Fastboot mode
adb reboot bootloader

# 2. Flash all images with AVB verification disabled (1-line command)
ANDROID_PRODUCT_OUT=out/target/product/tangorpro fastboot flashall -w --disable-verity --disable-verification
```

---

## ✅ Working Hardware & Subsystems Status Matrix

| Subsystem | Status | Technical Details |
| :--- | :--- | :--- |
| 🎨 **Graphics & Display** | 🟢 **Working** | Full 60fps Hardware-Accelerated UI via `libhwc2.1` Exynos HWC. |
| 📱 **Touchscreen & Stylus** | 🟢 **Working** | Accurate landscape digitizer mapping via `NVTCapacitiveTouchScreen.idc`. |
| 📶 **Wi-Fi (802.11ax)** | 🟢 **Working** | Fully functional via Tensor G2 Wi-Fi HAL. |
| 🔷 **Bluetooth 5.2** | 🟢 **Working** | Fully functional Bluetooth stack. |
| 🔊 **Audio & Routing** | 🟢 **Working** | Multizone `CarAudioService` with Dynamic Audio Routing enabled. |
| 🚗 **Automotive VHAL** | 🟢 **Working** | Mock VHAL initialized in `system_ext` with `CarSettings` support. |
| 🛡️ **Boot & Slot Safety** | 🟢 **Working** | BootControl HAL slot safety (`retry_count = 3`, `successful = 1`). |

---

## Phase 4: Device Recovery & Management

### Resetting the Bootloader Retry Count
If you ever need to manually inspect or set active boot slots in Fastboot:

```bash
# Check current slot
fastboot getvar all | grep current-slot
# Reset active slot
fastboot set_active a
# Reboot
fastboot reboot
```
