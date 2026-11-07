#!/bin/bash
# ==============================================================================
# BƯỚC 04: CẬP NHẬT NHANH BẢN VÁ DUAL-BOOT WARM-REBOOT CHO AX210 (GIỮ NGUYÊN MẠNG ĐÃ LƯU)
# Dành cho máy đã bật Wi-Fi Native nhưng muốn cập nhật riêng file kext AirportItlwm_Tahoe
# đã vá lỗi mất Wi-Fi khi Restart ấm từ Windows 11 sang macOS Tahoe (không xóa cấu hình mạng).
#
# Cách chạy:
#   sudo bash scripts/04-cap-nhat-wifi-dualboot-ax210.sh
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy bằng quyền sudo:"
  echo "  sudo bash scripts/04-cap-nhat-wifi-dualboot-ax210.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_KEXT="$REPO_DIR/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"

if [ ! -f "$SRC_KEXT/Contents/MacOS/AirportItlwm" ]; then
  echo "[LỖI] Không tìm thấy $SRC_KEXT!"
  exit 1
fi

if ! nm "$SRC_KEXT/Contents/MacOS/AirportItlwm" | grep "iwx_quiesce_warm_boot_hw" >/dev/null; then
  echo "[LỖI] Kext không chứa bản vá warm-reboot!"
  exit 1
fi

if ! kmutil libraries --bundle-path "$SRC_KEXT" >/dev/null 2>&1; then
  echo "[LỖI] Kernel ABI không khớp! Hãy chạy bash patches/build-airportitlwm-tahoe.sh trước."
  exit 1
fi

SRC_SHA=$(shasum -a 256 "$SRC_KEXT/Contents/MacOS/AirportItlwm" | awk '{print $1}')

MNT="/private/tmp/oc_efi_ax210_update"
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

rm -rf "$MNT/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"
cp -R "$SRC_KEXT" "$MNT/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"
xattr -cr "$MNT/EFI/OC/Kexts/AirportItlwm_Tahoe.kext" 2>/dev/null || true
dot_clean -m "$MNT/EFI" 2>/dev/null || true
sync

INST_SHA=$(shasum -a 256 "$MNT/EFI/OC/Kexts/AirportItlwm_Tahoe.kext/Contents/MacOS/AirportItlwm" | awk '{print $1}')
if [ "$INST_SHA" != "$SRC_SHA" ]; then
  echo "[LỖI] SHA-256 trên EFI không khớp!"
  exit 1
fi

echo "=================================================================="
echo "[HOÀN TẤT] Đã cập nhật AirportItlwm_Tahoe.kext (Warm-Reboot Fix) trên /dev/$EFI_DEV!"
echo "Giữ nguyên 100% các mạng Wi-Fi đã lưu. Hãy Restart máy để áp dụng."
echo "=================================================================="
