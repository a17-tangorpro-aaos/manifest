# LinkedIn Announcement Post Draft

### 🚀 Porting Android Automotive OS (AAOS) 17 to the Google Pixel Tablet (Tangorpro)!

I'm thrilled to announce a major developer milestone: successfully porting and boot-verifying **Android Automotive OS 17 (AOSP 17.0.0_r1)** on the physical **Google Pixel Tablet (tangorpro)**! 

Upgrading the entire Tensor-based device tree stack to Android 17 R1 was an intensive exercise in dependency resolution and system-level adaptation. Rather than just compile a system image, this required modifying and coordinating **over 22+ distinct repositories** across the AOSP tree!

Want to check out the project or build it yourself? I've open-sourced our custom central manifest and port configuration here:
🔗 **Manifest Repo:** [https://github.com/a17-tangorpro-aaos/manifest.git](https://github.com/a17-tangorpro-aaos/manifest.git)

---

### 🛠️ Quick Start & Build Configuration:
To sync, compile, and flash the port:

```bash
# 1. Initialize our custom manifest
repo init -u https://github.com/a17-tangorpro-aaos/manifest.git -b android-17.0.0_r1-tangorpro

# 2. Synchronize all source directories
repo sync -c -j$(nproc)

# 3. Setup Android environment and build target
. build/envsetup.sh
lunch aosp_tangorpro_car-trunk_staging-userdebug
m

# 4. Flash system images (use either fastboot flashall or our manual flashing helper script)
export ANDROID_PRODUCT_OUT=out/target/product/tangorpro
./flash_all_manual.sh
```

---

### 📂 Key Modified Repo Areas:

📁 **1. Kernel & Storage Drivers Integration**
*   **Kernel 6.1 Boot Modules Alignment (`device/google/tangorpro-kernels/6.1`):** Integrated proprietary prebuilt Tensor G2 storage controller drivers (`ufs` and `giga-physical-layer`), resolving system partition mount issues during bootloader initialization.

🎨 **2. Exynos Graphic Driver & GPU Acceleration**
*   Adapted **`hardware/google/graphics/gs101`** to compile the Exynos hardware compositor (`libhwc2.1`). This bypasses Soong build restrictions on legacy makefiles, bringing full **60fps GPU hardware acceleration** to the AAOS user interface.

🚗 **3. Vehicle HAL & Audio Zones Setup**
*   **VHAL & Audio HAL Routing:** Configured AIDL Vehicle HAL (VHAL) properties to allow default vehicle simulations. Mapped automotive multizone audio groups and streams to ensure proper routing across the tablet outputs.
*   Tuned settings profiles, layout overlays, and automotive properties in **`packages/apps/Car/Settings`** to fit the widescreen format.

🖐️ **4. Bluetooth Role Inversion & Touch IDC Files**
*   Configured **Bluetooth HAL overlays** to support automotive hands-free host profiles (reversing standard mobile device roles).
*   Injected widescreen Touch Option Configuration (`.idc`) files (`NVTCapacitiveTouchScreen.idc`, `NVTCapacitivePen.idc`) to map touch coordinates logic accurately.

🛡️ **5. Device Stability & Safety Override (`device/google/tangorpro` & `device/google/gs-common`)**
*   Patched the shared Tensor `gs-common` Boot Control HAL (both AIDL and HIDL 1.2 codebases) to enforce slot-safety and prevent bootloops during debugging.
*   Modified platform device makefiles to safely disable **Rescue Party** user-space crash-loops for a smooth developer flashing experience.

The entire build structure is ready for testing and expansion. I will be publishing a full porting guide and article soon—stay tuned!

#AndroidAutomotive #AAOS #AOSP #OSDevelopment #Android17 #SoftwareEngineering #PixelTablet #EmbeddedSystems #SystemsEngineering
