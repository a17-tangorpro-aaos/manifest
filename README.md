# Android Automotive OS 17 (AAOS) Port for Pixel Tablet (tangorpro)

This repository contains the manifest configuration to initialize and sync a complete build workspace for porting **Android Automotive OS 17 (AOSP 17.0.0_r1)** to the physical **Google Pixel Tablet (tangorpro)**.

---

## 🛠️ Architecture & Porting Strategy

To successfully boot and run Android Automotive OS 17 on the Pixel Tablet's hardware, this workspace uses a hybrid porting strategy:

### 1. Unified A17 Platform Base
Standard Android OS framework repositories are synced directly from Google's official `android-17.0.0_r1` tag. 
* **Custom Framework Swaps (13 repositories):** 13 core AOSP repositories (such as `platform/frameworks/base` and `platform/packages/apps/Car/SystemUI`) have been swapped out for forks located under the `a17-tangorpro-aaos` organization. These forks contain customizations for custom vehicle audio routing, AAOS overlays, and a custom automotive biometric PIN pad interface.

### 2. Ported Android 15 Hardware Adapters (8 repositories)
Google does not publish device trees or Tensor SoC configurations for commercial devices in the public generic AOSP 17 manifest.
* **The A15 Base:** 8 essential peripherals, GPU controllers, and Tensor G2 SoC config folders are originally based on the **Android 15 (`android-15.0.0_r1`)** Pixel Tablet release branches.
* **The A17 Graft:** These 8 repositories have been modified to resolve AOSP 17 Soong blueprint build errors, directory adjustments, and namespace conflicts, allowing them to compile seamlessly in the A17 build tree. They are checked out using the unified `android-17.0.0_r1-tangorpro` branch.

---

## 🚀 Workspace Setup & Sync

Use the following commands to initialize your environment and sync all generic AOSP repositories along with our custom adapted repositories:

```bash
# 1. Initialize the repo workspace using this custom manifest
repo init -u https://github.com/a17-tangorpro-aaos/manifest.git -b android-17.0.0_r1-tangorpro

# 2. Sync all codebases (generic AOSP + custom forks) to your local drive
repo sync -c -j$(nproc) --force-sync --no-tags --no-clone-bundle
```

---

## 🏗️ Building the OS

Once the workspace is fully synchronized, set up your shell environment and kick off the Automotive Tangorpro compilation:

```bash
# 1. Initialize AOSP environment commands
source build/envsetup.sh

# 2. Select the Pixel Tablet AAOS Lunch target
# (Typically configured as aosp_tangorpro_car-ap2a-userdebug or similar depending on product definition)
lunch aosp_tangorpro_car-ap2a-userdebug

# 3. Build the flashable system images
m -j$(nproc)
```

---

## 📲 Flashing standard images

After a successful compilation, connect your Pixel Tablet in **Fastboot Mode** and flash the images using the local flashing script or manual fastboot tools:

```bash
# Run your manual flashing sequence
./flash_all_manual.sh
```

---

## 🔍 Validation & Verification

### 1. Verify Biometric PIN Pad RRO Overlay
To ensure the custom Automotive-themed overlays for SystemUI are loaded and active:

```bash
adb shell cmd overlay dump com.android.systemui.car.rro
```

### 2. Verify Graphics Acceleration
To check if the GPU and display driver modules (ported from the A15 base) loaded successfully on the A17 kernel:

```bash
adb shell getprop | grep -E "gralloc|hwcomposer|egl"
adb shell dmesg | grep -iE "mali|drm|ion|exynos"
```
