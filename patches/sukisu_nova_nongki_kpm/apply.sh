#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_KSU="${SCRIPT_DIR}/0001-sukisu-nova-nongki-linux44-kpm.patch"
PATCH_KPIMG="${SCRIPT_DIR}/0002-kpimg-linux44-direct-pte-kpm.patch"
TOOLCHAIN_URL="https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/12.2.rel1/binrel/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf.tar.xz"
KP_REPO="https://github.com/SukiSU-Nova/SukiSU_KernelPatch_patch.git"
KPTOOLS_URL="https://raw.githubusercontent.com/SukiSU-Nova/SukiSU_patch/main/kpm/kptools-linux"

usage() {
    cat <<EOF
Usage:
  $0 patch-ksu [KernelSU_dir]
  $0 build-kpimg [work_dir]
  $0 patch-image <input_Image> <output_Image> [work_dir] [superkey]
EOF
}

patch_ksu() {
    local ksu_dir="${1:-KernelSU}"
    if [ ! -d "$ksu_dir" ]; then
        echo "[!] KernelSU directory not found: $ksu_dir" >&2
        exit 1
    fi
    if git -C "$ksu_dir" apply --check --reverse "$PATCH_KSU" >/dev/null 2>&1; then
        echo "[=] KSU non-GKI KPM patch already applied in $ksu_dir"
    else
        git -C "$ksu_dir" apply "$PATCH_KSU"
        echo "[+] Applied KSU non-GKI KPM patch to $ksu_dir"
    fi
}

ensure_aarch64_none_elf() {
    local work_dir="$1"
    if [ -n "${TARGET_COMPILE:-}" ] && command -v "${TARGET_COMPILE}gcc" >/dev/null 2>&1; then
        return 0
    fi
    if command -v aarch64-none-elf-gcc >/dev/null 2>&1; then
        TARGET_COMPILE="aarch64-none-elf-"
        return 0
    fi
    local tc_dir="${work_dir}/arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf"
    if [ ! -x "${tc_dir}/bin/aarch64-none-elf-gcc" ]; then
        echo "[+] Downloading arm-gnu-toolchain-12.2.rel1-x86_64-aarch64-none-elf..."
        mkdir -p "$work_dir"
        curl -fL -o "${work_dir}/tc.tar.xz" "$TOOLCHAIN_URL"
        tar -Jxf "${work_dir}/tc.tar.xz" -C "$work_dir"
        rm -f "${work_dir}/tc.tar.xz"
    fi
    TARGET_COMPILE="${tc_dir}/bin/aarch64-none-elf-"
}

build_kpimg() {
    local work_dir="${1:-/tmp/sukisu_nongki_kpm}"
    mkdir -p "$work_dir"
    ensure_aarch64_none_elf "$work_dir"

    local kp_dir="${work_dir}/SukiSU_KernelPatch_patch"
    if [ ! -d "$kp_dir/.git" ]; then
        git clone --depth=1 "$KP_REPO" "$kp_dir"
    fi
    if ! git -C "$kp_dir" apply --check --reverse "$PATCH_KPIMG" >/dev/null 2>&1; then
        git -C "$kp_dir" apply "$PATCH_KPIMG"
    fi

    (
        cd "$kp_dir/kernel"
        export TARGET_COMPILE
        export ANDROID=1
        make clean >/dev/null 2>&1 || true
        make kpimg -j"$(nproc)"
    )
    cp "${kp_dir}/kernel/kpimg" "${work_dir}/kpimg"

    if [ ! -x "${work_dir}/kptools-linux" ]; then
        curl -fL -o "${work_dir}/kptools-linux" "$KPTOOLS_URL"
        chmod +x "${work_dir}/kptools-linux"
    fi
    echo "[+] Built custom kpimg: ${work_dir}/kpimg"
}

patch_image() {
    local in_img="$1"
    local out_img="$2"
    local work_dir="${3:-/tmp/sukisu_nongki_kpm}"
    local skey="${4:-sukisu}"

    if [ ! -f "${work_dir}/kpimg" ] || [ ! -x "${work_dir}/kptools-linux" ]; then
        build_kpimg "$work_dir"
    fi

    "${work_dir}/kptools-linux" -p -i "$in_img" -k "${work_dir}/kpimg" -S "$skey" -o "$out_img"
    echo "[+] Patched kernel Image with non-GKI KPM: $out_img"
}

cmd="${1:-}"
case "$cmd" in
    patch-ksu)
        shift
        patch_ksu "$@"
        ;;
    build-kpimg)
        shift
        build_kpimg "$@"
        ;;
    patch-image)
        shift
        if [ $# -lt 2 ]; then
            usage
            exit 1
        fi
        patch_image "$@"
        ;;
    *)
        usage
        exit 1
        ;;
esac
