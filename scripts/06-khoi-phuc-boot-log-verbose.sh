#!/bin/bash
# ==============================================================================
# BƯỚC 06: KHÔI PHỤC CHẾ ĐỘ CHẠY CHỮ LOG (VERBOSE -v) KHI CẦN GỠ LỖI
# Cách chạy:
#   sudo bash scripts/06-khoi-phuc-boot-log-verbose.sh
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy với quyền sudo:"
  echo "  sudo bash scripts/06-khoi-phuc-boot-log-verbose.sh"
  exit 1
fi

MNT="/private/tmp/oc_efi_verbose"
mkdir -p "$MNT"
cleanup() {
  diskutil unmount "$MNT" >/dev/null 2>&1 || true
  rmdir "$MNT" 2>/dev/null || true
}
trap cleanup EXIT

EFI_DEV=""
for part in $(diskutil list internal | awk '/EFI/{print $NF}'); do
  if diskutil mount -mountPoint "$MNT" "/dev/$part" >/dev/null 2>&1; then
    if [ -f "$MNT/EFI/OC/config.plist" ]; then
      EFI_DEV="$part"
      break
    fi
    diskutil unmount "$MNT" >/dev/null 2>&1 || true
  fi
done

if [ -z "$EFI_DEV" ]; then
  echo "[LỖI] Không tìm thấy phân vùng OpenCore EFI!"
  exit 1
fi

NEW_ARGS=$(python3 - "$MNT/EFI/OC/config.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
with open(p, "rb") as f:
    cfg = plistlib.load(f)
apple_guid = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
nv_add = cfg["NVRAM"]["Add"][apple_guid]
tokens = [t for t in nv_add.get("boot-args", "").split() if t != "-v"]
new_args = "-v " + " ".join(tokens)
nv_add["boot-args"] = new_args.strip()
with open(p, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
print(nv_add["boot-args"])
PY
)

plutil -lint "$MNT/EFI/OC/config.plist" >/dev/null
dot_clean -m "$MNT/EFI" 2>/dev/null || true
sync
nvram boot-args="$NEW_ARGS" 2>/dev/null || true

echo "[OK] Đã bật lại cờ verbose (-v) trong config.plist & NVRAM (vẫn giữ giao diện OpenCanopy)!"
