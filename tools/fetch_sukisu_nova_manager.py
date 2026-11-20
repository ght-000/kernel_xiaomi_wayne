#!/usr/bin/env python3
import json
import os
import sys
import urllib.request


def fetch_manager(dest_dir="dist"):
    os.makedirs(dest_dir, exist_ok=True)
    url = "https://api.github.com/repos/SukiSU-Nova/SukiSU-Nova/releases/latest"
    headers = {"User-Agent": "Mozilla/5.0"}

    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=20) as resp:
        release = json.loads(resp.read().decode())

    target_url = None
    asset_name = None
    for asset in release.get("assets", []):
        name = asset.get("name", "")
        if "arm64-v8a" in name and name.endswith(".apk"):
            target_url = asset.get("browser_download_url")
            asset_name = name
            break

    if not target_url:
        raise RuntimeError("No arm64-v8a APK found in latest SukiSU-Nova release")

    out_file = os.path.join(dest_dir, asset_name)
    print(f"[+] Downloading {target_url} -> {out_file}")
    dl_req = urllib.request.Request(target_url, headers=headers)
    with urllib.request.urlopen(dl_req, timeout=60) as r, open(out_file, "wb") as f:
        f.write(r.read())
    print(f"[+] Saved manager APK: {out_file}")


if __name__ == "__main__":
    dest = sys.argv[1] if len(sys.argv) > 1 else "dist"
    fetch_manager(dest)
