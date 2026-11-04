#!/bin/bash
set -e

ENABLE_BAKASU=false
ENABLE_DROIDSPACES=false

for arg in "$@"; do
    case "$arg" in
        --bakasu) ENABLE_BAKASU=true ;;
        --droidspaces) ENABLE_DROIDSPACES=true ;;
        --all) ENABLE_BAKASU=true; ENABLE_DROIDSPACES=true ;;
    esac
done

export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE="${CROSS_COMPILE:-/root/toolchains/aarch64-linux-android-4.9/bin/aarch64-linux-android-}"

echo "=========================================="
echo " Building Xiaomi 6X (wayne) Kernel"
echo "   BakaSU (KernelSU): $ENABLE_BAKASU"
echo "   Droidspaces Containers: $ENABLE_DROIDSPACES"
echo "=========================================="

# 1. BakaSU Setup (if enabled)
if [ "$ENABLE_BAKASU" = "true" ]; then
    echo "[+] Setting up BakaSU (KernelSU)..."
    if [ ! -d "KernelSU" ]; then
        git clone https://github.com/Baka-SU/BakaSU.git KernelSU
        git -C KernelSU apply ../patches/0001-adb_root-android9-compat.patch 2>/dev/null || true
    fi
    rm -rf drivers/kernelsu
    ln -sf ../KernelSU/kernel drivers/kernelsu
fi

# 2. Base defconfig
make wayne-perf_defconfig

# 3. Droidspaces
if [ "$ENABLE_DROIDSPACES" = "true" ]; then
    echo "[+] Merging Droidspaces container config..."
    cat arch/arm64/configs/droidspaces.config >> .config
    make olddefconfig
fi

# 4. Finalize BakaSU config
if [ "$ENABLE_BAKASU" = "true" ]; then
    cat arch/arm64/configs/bakasu.config >> .config
    make olddefconfig
else
    echo "[-] Disabling BakaSU..."
    sed -i '/CONFIG_KSU/d' .config
    echo "# CONFIG_KSU is not set" >> .config
    make olddefconfig
fi

# 5. Compile kernel
make -j1 scripts prepare
make -j$(nproc) Image.gz-dtb

# 6. Packaging
OUT_DIR="out_artifacts"
mkdir -p "$OUT_DIR"

SUFFIX="wayne"
[ "$ENABLE_BAKASU" = "true" ] && SUFFIX="${SUFFIX}-bakasu"
[ "$ENABLE_DROIDSPACES" = "true" ] && SUFFIX="${SUFFIX}-droidspaces"

./tools/pack_ak3.sh arch/arm64/boot/Image.gz-dtb "$OUT_DIR/AnyKernel3-${SUFFIX}.zip"
./tools/pack_signed_boot.sh arch/arm64/boot/Image.gz-dtb "$OUT_DIR/boot.img"

echo "=========================================="
echo "[✓] Build complete! Output files in: $OUT_DIR/"
ls -lh "$OUT_DIR/"
echo "=========================================="
