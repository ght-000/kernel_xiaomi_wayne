#!/bin/bash
set -e

KERNEL_IMG="$1"
OUTPUT_IMG="$2"

if [ -z "$KERNEL_IMG" ] || [ -z "$OUTPUT_IMG" ]; then
    echo "Usage: $0 [path/to/Image.gz or Image.gz-dtb] [path/to/output_boot.img]"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$DIR/boot_template"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

if [ -f "$DIR/orig_dtbs.bin" ]; then
    echo "[+] Checking DTB bundle..."
    if ! grep -q -m 1 -a $'\xd0\x0d\xfe\xed' "$KERNEL_IMG"; then
        echo "[+] Appending complete Wayne DTB bundle (orig_dtbs.bin)..."
        cat "$KERNEL_IMG" "$DIR/orig_dtbs.bin" > "$TMP_DIR/kernel_with_dtb"
        KERNEL_TO_USE="$TMP_DIR/kernel_with_dtb"
    else
        KERNEL_TO_USE="$KERNEL_IMG"
    fi
else
    KERNEL_TO_USE="$KERNEL_IMG"
fi

python3 "$TEMPLATE/mkbootimg.py" \
  --kernel "$KERNEL_TO_USE" \
  --ramdisk "$TEMPLATE/initrd.img" \
  --cmdline 'console=ttyMSM0,115200,n8 androidboot.console=ttyMSM0 earlycon=msm_serial_dm,0xc170000 androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x37 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 sched_enable_hmp=1 sched_enable_power_aware=1 service_locator.enable=1 swiotlb=1 firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 buildvariant=user' \
  --base 0x00000000 \
  --pagesize 4096 \
  --kernel_offset 0x00008000 \
  --ramdisk_offset 0x01000000 \
  --second_offset 0x00f00000 \
  --tags_offset 0x00000100 \
  --os_version 9.0.0 \
  --os_patch_level 2020-11 \
  --output "$TMP_DIR/boot_raw.img"

java -jar "$TEMPLATE/bin/BootSignature.jar" /boot \
    "$TMP_DIR/boot_raw.img" \
    "$TEMPLATE/avb/verity.pk8" \
    "$TEMPLATE/avb/verity.x509.pem" \
    "$OUTPUT_IMG"

echo "[+] Successfully generated signed boot image: $OUTPUT_IMG"
