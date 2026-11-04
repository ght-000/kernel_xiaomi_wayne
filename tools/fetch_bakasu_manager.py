#!/usr/bin/env python3
import json
import os
import re
import shutil
import sys
import urllib.request

def fetch_manager(dest_dir="dist", target_version=None):
    os.makedirs(dest_dir, exist_ok=True)
    target_ver_str = str(target_version) if target_version else "35257"
    out_file = os.path.join(dest_dir, f"BakaSU-Manager-{target_ver_str}.apk")

    # 1. Local bundled APK check (e.g. tools/BakaSU-Manager-35257.apk)
    local_apk = f"tools/BakaSU-Manager-{target_ver_str}.apk"
    if os.path.exists(local_apk):
        print(f"[+] Using local bundled APK: {local_apk} -> {out_file}")
        shutil.copyfile(local_apk, out_file)
        return

    # 2. Query GitHub Releases for tagged versions
    url = "https://api.github.com/repos/Baka-SU/BakaSU/releases"
    headers = {"User-Agent": "Mozilla/5.0"}
    target_url = None

    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=15) as resp:
            releases = json.loads(resp.read().decode())

        for rel in releases:
            for asset in rel.get("assets", []):
                name = asset.get("name", "")
                if "arm64-v8a" in name and name.endswith(".apk"):
                    if target_version and str(target_version) in name:
                        target_url = asset.get("browser_download_url")
                        break
                    elif not target_version and not target_url:
                        target_url = asset.get("browser_download_url")
            if target_url:
                break
    except Exception as e:
        print(f"[-] GitHub API query failed: {e}")

    # 3. Download if URL found, else fallback to bundled 35257
    if target_url:
        print(f"[+] Downloading {target_url} -> {out_file}...")
        urllib.request.urlretrieve(target_url, out_file)
    else:
        fallback = "tools/BakaSU-Manager-35257.apk"
        if os.path.exists(fallback):
            print(f"[-] Falling back to {fallback} -> {out_file}")
            shutil.copyfile(fallback, out_file)
        else:
            print("[-] No APK found")

    if os.path.exists(out_file):
        print(f"[✓] Deployed: {out_file} ({os.path.getsize(out_file)} bytes)")

if __name__ == "__main__":
    dest = sys.argv[1] if len(sys.argv) > 1 else "dist"
    ver = sys.argv[2] if len(sys.argv) > 2 else None
    fetch_manager(dest, ver)
