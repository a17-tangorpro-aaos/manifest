# LinkedIn Announcement Post Draft

🚀 Just successfully ported and booted Android Automotive OS 17 (AOSP 17.0.0_r1) on the physical Google Pixel Tablet (tangorpro).

Getting a mobile-focused tablet running a modern, automotive AOSP tree requires aligning a lot of low-level hardware modules. Overall, we ended up customizing or tracking over 22+ different repositories to stabilize this configuration.

🔑 Key areas of the porting process:

- 💻 Kernel storage alignment: Integrated the proprietary prebuilt Tensor G2 storage controller drivers (UFS and physical layer) into our local manifest to prevent boot-time filesystem mount loops.
- 🎨 GPU acceleration: Adapted hardware/google/graphics/gs101 to build the Exynos hardware compositor (libhwc2.1). This bypasses Soong build restrictions on legacy makefiles, bringing full 60fps hardware-accelerated drawing to the UI.
- 🚗 Vehicle simulation & Audio routing: Mapped mock Vehicle HAL properties to allow automotive service initialization and grouped tablet outputs into multizone audio profiles to prevent HAL crash-loops.
- 📱 Stylus & Touch digitizer mapping: Injected Touch Device Configuration (.idc) overrides (NVTCapacitiveTouchScreen.idc) to map touch coordinates accurately in widescreen orientation.
- 🛡️ Slot safety: Patched the Tensor gs-common Boot Control HAL (both AIDL and HIDL 1.2 implementations) to reset slot retry counts to 3 on boot, preventing the bootloader from locking active slots during debugging. We also disabled platform Rescue Party triggers.

The manifest repository containing the port configurations is open-source here:
https://github.com/a17-tangorpro-aaos/manifest.git

🔧 Quick start guide to sync, compile, and flash:

```bash
# 1. Initialize custom manifest
repo init -u https://github.com/a17-tangorpro-aaos/manifest.git -b android-17.0.0_r1-tangorpro

# 2. Sync source code
repo sync -c -j$(nproc)

# 3. Set up build profile and compile
. build/envsetup.sh
lunch aosp_tangorpro_car-trunk_staging-userdebug
m

# 4. Flash build to hardware (using our manual flashing helper)
export ANDROID_PRODUCT_OUT=out/target/product/tangorpro
./flash_all_manual.sh
```

More details and documentation are available in the repository's README. I'll be publishing a full porting guide soon.

#AOSP #AndroidAutomotive #AAOS #OSDevelopment #EmbeddedSystems
