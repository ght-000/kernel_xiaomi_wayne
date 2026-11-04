#!/bin/bash
set -e

KERNEL_IMG="$1"
OUTPUT_ZIP="$2"

if [ -z "$KERNEL_IMG" ] || [ -z "$OUTPUT_ZIP" ]; then
    echo "Usage: $0 [path/to/Image.gz or Image.gz-dtb] [path/to/output.zip]"
    exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AK3_DIR="$DIR/AnyKernel3"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

cp -r "$AK3_DIR"/* "$TMP_DIR"/

if [ -f "$DIR/orig_dtbs.bin" ]; then
    if ! grep -q -m 1 -a $'\xd0\x0d\xfe\xed' "$KERNEL_IMG"; then
        echo "[+] Appending complete Wayne DTB bundle to Image.gz-dtb for AnyKernel3..."
        cat "$KERNEL_IMG" "$DIR/orig_dtbs.bin" > "$TMP_DIR/Image.gz-dtb"
    else
        cp "$KERNEL_IMG" "$TMP_DIR/Image.gz-dtb"
    fi
else
    cp "$KERNEL_IMG" "$TMP_DIR/Image.gz-dtb"
fi

OUTPUT_ZIP_ABS="$(readlink -f "$OUTPUT_ZIP" 2>/dev/null || realpath "$OUTPUT_ZIP")"

cd "$TMP_DIR"
zip -r9 "$OUTPUT_ZIP_ABS" ./* -x "README.md" "LICENSE"

echo "[+] Successfully generated AnyKernel3 zip: $OUTPUT_ZIP"
