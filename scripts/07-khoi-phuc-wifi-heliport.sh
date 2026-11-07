#!/bin/bash
# ==============================================================================
# BƯỚC 07: CHUYỂN DỰ PHÒNG SANG CHẾ ĐỘ HELIPORT (itlwm.kext) CHỈ VỚI 1 LỆNH
# Hữu ích khi Apple vừa phát hành bản cập nhật macOS lớn làm đổi Kernel ABI mà bạn
# chưa kịp biên dịch lại AirportItlwm_Tahoe.kext bằng patches/build-airportitlwm-tahoe.sh.
#
# Cách chạy:
#   sudo bash scripts/07-khoi-phuc-wifi-heliport.sh
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy với quyền sudo:"
  echo "  sudo bash scripts/07-khoi-phuc-wifi-heliport.sh"
  exit 1
fi

MNT="/private/tmp/oc_efi_heliport"
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

python3 - "$MNT/EFI/OC/config.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
with open(p, "rb") as f:
    cfg = plistlib.load(f)
for entry in cfg["Kernel"]["Add"]:
    if entry.get("BundlePath") == "AirportItlwm_Tahoe.kext":
        entry["Enabled"] = False
    elif entry.get("BundlePath") == "itlwm.kext":
        entry["Enabled"] = True
        entry["MinKernel"] = "25.0.0"
        entry["MaxKernel"] = "25.99.99"
with open(p, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
PY

plutil -lint "$MNT/EFI/OC/config.plist" >/dev/null
dot_clean -m "$MNT/EFI" 2>/dev/null || true
sync

rm -f /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist \
      /Library/Preferences/SystemConfiguration/preferences.plist

echo "[OK] Đã chuyển sang itlwm.kext. Hãy cài đặt HeliPort.app, Restart máy và kết nối Wi-Fi qua HeliPort!"
