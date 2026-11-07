#!/bin/bash
# ==============================================================================
# BƯỚC 01: CHUẨN BỊ OPENCORE EFI TRƯỚC KHI NÂNG CẤP TỪ SEQUOIA 15 LÊN TAHOE 26
# Dành cho máy đang chạy macOS Sequoia 15 muốn nâng cấp trực tiếp hoặc cài song song
# lên macOS Tahoe 26:
# - Tự động sao lưu toàn bộ EFI hiện tại
# - Giới hạn các kext OCLP cũ của Sequoia (IOSkywalkFamily, IO80211FamilyLegacy,
#   AirportItlwm cũ) ở Darwin 24.0.0 -> 24.99.99 để không gây Kernel Panic trên Tahoe 26
# - Bổ sung sẵn AirportItlwm_Tahoe.kext (Darwin 25.x) + itlwm.kext dự phòng
#
# Cách chạy:
#   sudo bash scripts/01-chuan-bi-len-tahoe.sh
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy bằng quyền sudo:"
  echo "  sudo bash scripts/01-chuan-bi-len-tahoe.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS=$(date +"%Y%m%d-%H%M%S")
BACKUP_ROOT="$HOME/Desktop/EFI-Backup-Truoc-Tahoe-$TS"

MNT="/private/tmp/oc_efi_prep_tahoe"
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
  echo "[LỖI] Không tìm thấy phân vùng OpenCore EFI trên ổ cứng trong!"
  exit 1
fi

echo "[1/3] Sao lưu toàn bộ EFI hiện tại ra: $BACKUP_ROOT"
cp -R "$MNT/EFI" "$BACKUP_ROOT"
cp -f "$MNT/EFI/OC/config.plist" "$MNT/EFI/OC/config.plist.bak-before-tahoe"

echo "[2/3] Chép AirportItlwm_Tahoe.kext & itlwm.kext dự phòng vào EFI/OC/Kexts..."
for kname in AirportItlwm_Tahoe.kext itlwm.kext; do
  if [ -d "$REPO_DIR/EFI/OC/Kexts/$kname" ]; then
    rm -rf "$MNT/EFI/OC/Kexts/$kname"
    cp -R "$REPO_DIR/EFI/OC/Kexts/$kname" "$MNT/EFI/OC/Kexts/$kname"
    xattr -cr "$MNT/EFI/OC/Kexts/$kname" 2>/dev/null || true
  fi
done

echo "[3/3] Cấu hình Dual-Kernel (Sequoia 24.x + Tahoe 25.x) trong config.plist..."
python3 - "$MNT/EFI/OC/config.plist" <<'PY'
import plistlib, sys

cfg_path = sys.argv[1]
with open(cfg_path, "rb") as f:
    cfg = plistlib.load(f)

k_add = cfg["Kernel"]["Add"]
k_block = cfg["Kernel"].get("Block", [])

for entry in k_add:
    bp = entry.get("BundlePath", "")
    if bp in ("IOSkywalkFamily.kext", "IO80211FamilyLegacy.kext", "AirportItlwm.kext"):
        entry["MinKernel"] = "24.0.0"
        entry["MaxKernel"] = "24.99.99"

for blk in k_block:
    if blk.get("Identifier") == "com.apple.iokit.IOSkywalkFamily":
        blk["MinKernel"] = "24.0.0"
        blk["MaxKernel"] = "24.99.99"
    elif blk.get("Identifier") == "com.apple.iokit.IONDRVSupport":
        blk["MaxKernel"] = ""

def upsert_kext(bundle_path, exec_path, enabled, comment):
    item = {
        "Arch": "x86_64",
        "BundlePath": bundle_path,
        "Comment": comment,
        "Enabled": enabled,
        "ExecutablePath": exec_path,
        "MaxKernel": "25.99.99",
        "MinKernel": "25.0.0",
        "PlistPath": "Contents/Info.plist",
    }
    for i, e in enumerate(k_add):
        if e.get("BundlePath") == bundle_path:
            k_add[i] = item
            return
    k_add.append(item)

upsert_kext("itlwm.kext", "Contents/MacOS/itlwm", False, "Fallback Intel Wi-Fi for Tahoe 26 (HeliPort)")
upsert_kext("AirportItlwm_Tahoe.kext", "Contents/MacOS/AirportItlwm", True, "Native Intel Wi-Fi for macOS Tahoe 26 (AX210 warm-reboot fix)")

with open(cfg_path, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
PY

plutil -lint "$MNT/EFI/OC/config.plist" >/dev/null
dot_clean -m "$MNT/EFI" 2>/dev/null || true
sync

echo "=================================================================="
echo "[HOÀN TẤT] Phân vùng EFI (/dev/$EFI_DEV) đã sẵn sàng cho cả Sequoia 15 & Tahoe 26!"
echo "Bây giờ bạn có thể chạy 'Install macOS Tahoe.app' để nâng cấp."
echo "=================================================================="
