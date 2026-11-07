#!/bin/bash
# ==============================================================================
# BƯỚC 03: KÍCH HOẠT WI-FI NATIVE APPLE CHO INTEL AX210 TRÊN MACOS TAHOE 26
# - Dùng trực tiếp biểu tượng Wi-Fi gốc của macOS (System Settings -> Wi-Fi),
#   KHÔNG cần HeliPort, KHÔNG cần OCLP Root Patch (giữ nguyên ổ hệ thống Sealed: Yes!)
# - Đã tích hợp sẵn bản vá C++ Dual-Boot Warm-Reboot (Windows 11 <-> macOS Tahoe)
# - Tự kiểm tra tương thích Kernel ABI (kmutil libraries) trước khi ghi vào EFI
#
# Cách chạy:
#   sudo bash scripts/03-kich-hoat-wifi-native-ax210.sh
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy bằng quyền sudo:"
  echo "  sudo bash scripts/03-kich-hoat-wifi-native-ax210.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_KEXT="$REPO_DIR/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"
OCVALIDATE="$REPO_DIR/tools/ocvalidate/ocvalidate"
TS=$(date +"%Y%m%d-%H%M%S")

echo "[1/5] Kiểm tra toàn vẹn AirportItlwm_Tahoe.kext & tương thích Kernel ABI..."
if [ ! -f "$SRC_KEXT/Contents/MacOS/AirportItlwm" ]; then
  echo "[LỖI] Không tìm thấy $SRC_KEXT"
  exit 1
fi

if ! nm "$SRC_KEXT/Contents/MacOS/AirportItlwm" | grep "iwx_quiesce_warm_boot_hw" >/dev/null; then
  echo "[LỖI] AirportItlwm thiếu bản vá warm-reboot iwx_quiesce_warm_boot_hw!"
  exit 1
fi

if ! kmutil libraries --bundle-path "$SRC_KEXT" >/dev/null 2>&1; then
  echo "[LỖI] Kernel ABI của bản macOS hiện tại đã thay đổi so với kext biên dịch sẵn!"
  echo "Hãy chạy: bash patches/build-airportitlwm-tahoe.sh để build lại cho bản macOS mới."
  exit 1
fi
SRC_SHA=$(shasum -a 256 "$SRC_KEXT/Contents/MacOS/AirportItlwm" | awk '{print $1}')
echo "    [OK] Kernel ABI tương thích 100% (SHA-256: $SRC_SHA)"

echo "[2/5] Mount phân vùng OpenCore EFI & sao lưu an toàn..."
MNT="/private/tmp/oc_efi_wifi_native"
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

cp -f "$MNT/EFI/OC/config.plist" "$MNT/EFI/OC/config.plist.before-native-wifi-$TS"

echo "[3/5] Cài đặt AirportItlwm_Tahoe.kext vào EFI/OC/Kexts..."
rm -rf "$MNT/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"
cp -R "$SRC_KEXT" "$MNT/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"
xattr -cr "$MNT/EFI/OC/Kexts/AirportItlwm_Tahoe.kext" 2>/dev/null || true

INST_SHA=$(shasum -a 256 "$MNT/EFI/OC/Kexts/AirportItlwm_Tahoe.kext/Contents/MacOS/AirportItlwm" | awk '{print $1}')
if [ "$INST_SHA" != "$SRC_SHA" ]; then
  echo "[LỖI] SHA-256 sau khi chép vào EFI không khớp! Đang khôi phục..."
  cp -f "$MNT/EFI/OC/config.plist.before-native-wifi-$TS" "$MNT/EFI/OC/config.plist"
  exit 1
fi

echo "[4/5] Cập nhật EFI/OC/config.plist (Tắt itlwm, bật AirportItlwm_Tahoe cho Darwin 25.x)..."
python3 - "$MNT/EFI/OC/config.plist" <<'PY'
import plistlib, sys

cfg_path = sys.argv[1]
with open(cfg_path, "rb") as f:
    cfg = plistlib.load(f)

k_add = cfg["Kernel"]["Add"]
for entry in k_add:
    bp = entry.get("BundlePath", "")
    if bp in ("IOSkywalkFamily.kext", "IO80211FamilyLegacy.kext", "AirportItlwm.kext"):
        entry["MinKernel"] = entry.get("MinKernel") or "24.0.0"
        entry["MaxKernel"] = entry.get("MaxKernel") or "24.99.99"
    elif bp == "itlwm.kext":
        entry["Enabled"] = False

tahoe_entry = {
    "Arch": "x86_64",
    "BundlePath": "AirportItlwm_Tahoe.kext",
    "Comment": "Native Intel Wi-Fi for macOS Tahoe 26 (AX210 dual-boot warm-reboot fix)",
    "Enabled": True,
    "ExecutablePath": "Contents/MacOS/AirportItlwm",
    "MaxKernel": "25.99.99",
    "MinKernel": "25.0.0",
    "PlistPath": "Contents/Info.plist",
}
idx = next((i for i, e in enumerate(k_add) if e.get("BundlePath") == "AirportItlwm_Tahoe.kext"), None)
if idx is not None:
    k_add[idx] = tahoe_entry
else:
    k_add.append(tahoe_entry)

with open(cfg_path, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
PY

plutil -lint "$MNT/EFI/OC/config.plist" >/dev/null
if [ -x "$OCVALIDATE" ]; then
  OCV_OUT=$("$OCVALIDATE" "$MNT/EFI/OC/config.plist" 2>&1 || true)
  if ! printf '%s\n' "$OCV_OUT" | grep "No issues found." >/dev/null; then
    echo "[CẢNH BÁO] Kết quả ocvalidate:"
    printf '%s\n' "$OCV_OUT"
  fi
fi

dot_clean -m "$MNT/EFI" 2>/dev/null || true
sync
diskutil unmount "$MNT" >/dev/null 2>&1 || true
rmdir "$MNT" 2>/dev/null || true

echo "[5/5] Làm mới ánh xạ card mạng & gỡ sạch HeliPort / dịch vụ OCLP cũ dư thừa..."
rm -f /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist \
      /Library/Preferences/SystemConfiguration/preferences.plist
killall HeliPort 2>/dev/null || true
rm -rf /Applications/HeliPort.app
osascript -e 'tell application "System Events" to delete (every login item whose name is "HeliPort")' 2>/dev/null || true

launchctl bootout system/com.dortania.opencore-legacy-patcher.macos-update 2>/dev/null || true
if [ -n "${SUDO_UID:-}" ]; then
  launchctl bootout "gui/$SUDO_UID/com.dortania.opencore-legacy-patcher.auto-patch" 2>/dev/null || true
fi
rm -f /Library/LaunchDaemons/com.dortania.opencore-legacy-patcher.macos-update.plist \
      /Library/LaunchAgents/com.dortania.opencore-legacy-patcher.auto-patch.plist
rm -rf "/Library/Application Support/Dortania"

echo "=================================================================="
echo "[HOÀN TẤT] Đã bật Wi-Fi Native Apple (AX210) trên macOS Tahoe 26!"
echo "Hãy khởi động lại máy (Restart) để nhận menu Wi-Fi gốc của macOS."
echo "=================================================================="
