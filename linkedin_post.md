# LinkedIn Announcement & Technical Article Draft

🚀 **Just successfully brought up and booted Android Automotive OS 17 (AOSP android-17.0.0_r1) on the physical Google Pixel Tablet (`tangorpro`)!**

Getting a mobile-focused tablet running a modern automotive AOSP tree requires aligning low-level hardware modules across the entire system stack. Overall, we ended up customizing and tracking **22+ different repositories** to stabilize this configuration.

---

### 🔑 Key Engineering Highlights & Deep Dive:

- 💻 **Kernel Storage Alignment:** Integrated proprietary prebuilt Tensor G2 storage controller drivers (UFS and physical layer) into our local manifest to prevent boot-time filesystem mount loops.
- 🎨 **60fps GPU Acceleration:** Adapted `hardware/google/graphics/gs101` to build the Exynos hardware compositor (`libhwc2.1`). This bypasses Soong build restrictions on legacy makefiles, bringing full 60fps hardware-accelerated drawing to the AAOS UI.
- 🚗 **Vehicle Simulation & Audio Routing:** Relocated Vehicle HAL (VHAL) and AudioControl HAL into `system_ext` (`type="framework"`), mapped mock VHAL properties for service initialization, and enabled `ro.car.audio.useDynamicRouting=true` for CarSettings sound zone compatibility.
- 📱 **Stylus & Touch Digitizer Mapping:** Injected Touch Device Configuration (`.idc`) overrides (`NVTCapacitiveTouchScreen.idc`) to map touch and stylus coordinates accurately in landscape orientation.
- 🛡️ **Slot Safety & EDL Prevention:** Patched the Tensor `gs-common` Boot Control HAL (both AIDL and HIDL 1.2 implementations) to reset slot retry counts to 3 on boot (`unbootable = 0`, `retry_count = 3`, `successful = 1`). This prevents the bootloader from locking active slots into Exynos EDL mode (`18d1:4f00`) during debugging. We also disabled platform Rescue Party triggers and configured `panic=0` in kernel cmdline.
- 🛑 **System Server & Crash Loop Protection:** Configured `PackageManagerService` package installer dependencies to ensure clean, stable `system_server` startup without crash loops on initial bring-up.

---

### ✅ Working Hardware & Subsystems Status Matrix

| Subsystem | Status | Notes |
| :--- | :--- | :--- |
| 🎨 **Graphics & Display** | 🟢 **Working** | Full 60fps Hardware-Accelerated UI via `libhwc2.1` Exynos HWC. |
| 📱 **Touchscreen & Stylus** | 🟢 **Working** | Accurate landscape digitizer mapping via `NVTCapacitiveTouchScreen.idc`. |
| 📶 **Wi-Fi (802.11ax)** | 🟢 **Working** | Fully functional via Tensor G2 Wi-Fi HAL. |
| 🔷 **Bluetooth 5.2** | 🟢 **Working** | Fully functional Bluetooth stack. |
| 🔊 **Audio & Routing** | 🟢 **Working** | Multizone `CarAudioService` with Dynamic Audio Routing enabled. |
| 🚗 **Automotive VHAL** | 🟢 **Working** | Mock VHAL initialized in `system_ext` with `CarSettings` support. |
| 🛡️ **Boot & Slot Safety** | 🟢 **Working** | BootControl HAL slot safety (`retry_count = 3`, `successful = 1`). |

---

### 🌐 Open Source Manifest Repository

The custom manifest repository containing all 22+ tracked repositories and configurations is open-source here:
👉 **GitHub Manifest:** [https://github.com/a17-tangorpro-aaos/manifest.git](https://github.com/a17-tangorpro-aaos/manifest.git) (Branch: `android-17.0.0_r1-tangorpro`)

---

### 🔧 Quick Start Guide: Sync, Compile, and Flash

```bash
# 1. Initialize custom manifest
repo init -u https://github.com/a17-tangorpro-aaos/manifest.git -b android-17.0.0_r1-tangorpro

# 2. Sync all 22+ tracked source repositories
repo sync -c -j$(nproc)

# 3. Set up build profile and compile
source build/envsetup.sh
lunch aosp_tangorpro_car-trunk_staging-userdebug
m -j$(nproc)

# 4. Flash build to hardware (with AVB disabled)
adb reboot bootloader
fastboot --disable-verity --disable-verification flashall -w

# 5. Lock display orientation to landscape (Post-Boot)
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
```

---

### 📸 Result

Once booted, the Pixel Tablet displays the full Android Automotive OS 17 (Baklava) Home Screen and CarSettings interface in landscape orientation:

![AAOS 16 Home Screen & CarSettings](/home/hemang/.gemini/antigravity/brain/dcb160ff-aee5-477a-9b1b-5a27a147ea54/baklava_settings_screen_2.png)

More details and complete technical documentation are available in the repository's README!

#AOSP #AndroidAutomotive #AAOS #PixelTablet #Android16 #OSDevelopment #EmbeddedSystems #AutomotiveSoftware #Treble
