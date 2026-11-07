#!/bin/bash
# ==============================================================================
# BƯỚC 10: CHÉP BỘ OPENCORE EFI TỪ USB VÀO Ổ CỨNG NVMe (DUAL-BOOT CÙNG WINDOWS 11)
# - Dành cho bạn nào vừa cài mới macOS Tahoe 26 từ USB xong và muốn tháo USB ra
#   để máy tự khởi động trực tiếp từ ổ cứng NVMe!
# - CAM KẾT AN TOÀN TUYỆT ĐỐI CHO WINDOWS 11:
#   + TUYỆT ĐỐI KHÔNG ĐỤNG VÀO thư mục EFI/Microsoft (Windows Boot Manager)!
#   + Chỉ cập nhật đúng 2 thư mục EFI/Boot và EFI/OC cạnh EFI/Microsoft.
#   + Tự động kiểm tra mã Serial (nếu đang là W00000000001 sẽ tự sinh Serial riêng!).
#   + Kiểm định bằng ocvalidate + plutil -lint + dot_clean trước khi đóng ổ.
#
# Cách chạy:
#   sudo bash scripts/10-chep-efi-usb-vao-nvme-dualboot.sh
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy với quyền sudo:"
  echo "  sudo bash scripts/10-chep-efi-usb-vao-nvme-dualboot.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Xác định ổ đĩa vật lý chứa phân vùng macOS đang chạy (/)
ROOT_PART=$(diskutil info / | awk -F': *' '/Device Node/{print $2}')
PHYS_DISK=$(diskutil info / | awk -F': *' '/Part of Whole/{print $2}')
# Nếu / là APFS synthesized container, dò ngược về physical store
CONTAINER_STORE=$(diskutil apfs list "$PHYS_DISK" 2>/dev/null | awk '/APFS Physical Store Disk/{print $NF; exit}' || true)
if [ -n "$CONTAINER_STORE" ]; then
  NVME_DISK=$( printf '%s' "$CONTAINER_STORE" | sed -E 's/s[0-9]+$//' )
else
  NVME_DISK="$PHYS_DISK"
fi

TARGET_ESP=$(diskutil list "$NVME_DISK" | awk '/EFI/{print $NF; exit}')
if [ -z "$TARGET_ESP" ]; then
  echo "[LỖI] Không tìm thấy phân vùng EFI System Partition (ESP) trên ổ $NVME_DISK!"
  exit 1
fi

echo "=================================================================="
echo "CÀI ĐẶT OPENCORE LÊN Ổ CỨNG NVMe NỘI BỘ (DUAL-BOOT WINDOWS 11 + MACOS)"
echo "  Ổ macOS hiện tại : $ROOT_PART (thuộc ổ vật lý /dev/$NVME_DISK)"
echo "  Phân vùng ESP đích: /dev/$TARGET_ESP"
echo "=================================================================="

# 2. Chọn nguồn EFI ưu tiên: nếu đang boot từ USB có OpenCore đã cấu hình sẵn thì lấy từ USB đó,
#    nếu không thì lấy từ thư mục REPO_DIR/EFI
SRC_EFI="$REPO_DIR/EFI"
USB_MNT="/private/tmp/oc_usb_src"
mkdir -p "$USB_MNT"
for ext_esp in $(diskutil list external 2>/dev/null | awk '/EFI/{print $NF}'); do
  if diskutil mount -mountPoint "$USB_MNT" "/dev/$ext_esp" >/dev/null 2>&1; then
    if [ -f "$USB_MNT/EFI/OC/config.plist" ]; then
      SRC_EFI="$USB_MNT/EFI"
      echo "[1/4] Phát hiện bộ OpenCore đang chạy trên USB (/dev/$ext_esp) — dùng làm nguồn chuẩn!"
      break
    fi
    diskutil unmount "$USB_MNT" >/dev/null 2>&1 || true
  fi
done

if [ "$SRC_EFI" = "$REPO_DIR/EFI" ]; then
  echo "[1/4] Sử dụng bộ OpenCore chuẩn từ thư mục repo: $SRC_EFI"
fi

DST_MNT="/private/tmp/oc_nvme_dst"
mkdir -p "$DST_MNT"

cleanup() {
  diskutil unmount "$DST_MNT" >/dev/null 2>&1 || true
  diskutil unmount "$USB_MNT" >/dev/null 2>&1 || true
  rmdir "$DST_MNT" "$USB_MNT" 2>/dev/null || true
}
trap cleanup EXIT

diskutil mount -mountPoint "$DST_MNT" "/dev/$TARGET_ESP" >/dev/null

# Kiểm tra thư mục Microsoft của Windows 11
if [ -d "$DST_MNT/EFI/Microsoft" ]; then
  echo "[2/4] Đã tìm thấy EFI/Microsoft (Windows Boot Manager) — CAM KẾT GIỮ NGUYÊN 100%!"
else
  echo "[2/4] Phân vùng ESP chưa có EFI/Microsoft (máy chạy độc lập hoặc Windows nằm ở ổ cứng khác)."
fi

# Kiểm tra dung lượng trống trên ESP (cần tối thiểu ~35 MB cho OpenCore + Kexts + GoldenGate 4K)
FREE_KB=$(df -k "$DST_MNT" | awk 'NR==2{print $4}')
if [ "${FREE_KB:-0}" -lt 35000 ] && [ ! -d "$DST_MNT/EFI/OC" ]; then
  echo "[LỖI] Phân vùng EFI (/dev/$TARGET_ESP) chỉ còn $((FREE_KB / 1024)) MB trống (cần >= 35 MB)!"
  echo "Hãy mở rộng phân vùng EFI lên 200-300 MB trước khi chép."
  exit 1
fi

# Sao lưu EFI/OC cũ ra ~/Desktop nếu có (không lưu trên ESP để tránh đầy ESP 100MB của Windows!)
CONSOLE_USER=$(stat -f %Su /dev/console 2>/dev/null || echo "")
BACKUP_ROOT="/private/tmp"
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ] && [ -d "/Users/$CONSOLE_USER/Desktop" ]; then
  BACKUP_ROOT="/Users/$CONSOLE_USER/Desktop"
fi

if [ -d "$DST_MNT/EFI/OC" ]; then
  BK_DIR="$BACKUP_ROOT/EFI-NVMe-Backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BK_DIR"
  cp -R "$DST_MNT/EFI/OC" "$BK_DIR/OC"
  [ -d "$DST_MNT/EFI/Boot" ] && cp -R "$DST_MNT/EFI/Boot" "$BK_DIR/Boot"
  echo "      Đã sao lưu bộ EFI cũ ra: $BK_DIR"
fi

echo "[3/4] Đang sao chép EFI/Boot và EFI/OC vào /dev/$TARGET_ESP..."
mkdir -p "$DST_MNT/EFI"
rm -rf "$DST_MNT/EFI/OC" "$DST_MNT/EFI/Boot"
cp -R "$SRC_EFI/Boot" "$DST_MNT/EFI/Boot"
cp -R "$SRC_EFI/OC"   "$DST_MNT/EFI/OC"

# Đảm bảo không dùng Serial mẫu W00000000001 trên ổ cứng thật
CUR_SER=$(plutil -extract PlatformInfo.Generic.SystemSerialNumber raw -o - "$DST_MNT/EFI/OC/config.plist" 2>/dev/null || echo "")
if [ "$CUR_SER" = "W00000000001" ] || [ -z "$CUR_SER" ]; then
  echo "      Phát hiện Serial mẫu W00000000001 — đang tự động tạo SMBIOS MacPro7,1 riêng..."
  GEN_LINE=$("$REPO_DIR/tools/macserial/macserial" -m MacPro7,1 -n 1 | head -n 1)
  SERIAL=$(printf '%s' "$GEN_LINE" | awk -F' \\| ' '{gsub(/[[:space:]]/, "", $1); print $1}')
  MLB=$(printf '%s' "$GEN_LINE" | awk -F' \\| ' '{gsub(/[[:space:]]/, "", $2); print $2}')
  UUID=$(uuidgen | tr '[:lower:]' '[:upper:]')
  ROM_HEX=$(ifconfig en0 2>/dev/null | awk '/ether /{gsub(/:/, "", $2); print toupper($2)}' | head -n 1 || true)
  [ "${#ROM_HEX}" -ne 12 ] && ROM_HEX=$(python3 -c 'import secrets; b=bytearray(secrets.token_bytes(6)); b[0]=(b[0]&0xFE)|0x02; print(b.hex().upper())')
  python3 - "$DST_MNT/EFI/OC/config.plist" "$SERIAL" "$MLB" "$UUID" "$ROM_HEX" <<'PY'
import plistlib, sys
p, s, m, u, r = sys.argv[1:6]
with open(p, "rb") as f:
    cfg = plistlib.load(f)
g = cfg["PlatformInfo"]["Generic"]
g["SystemProductName"] = "MacPro7,1"
g["SystemSerialNumber"] = s
g["MLB"] = m
g["SystemUUID"] = u
g["ROM"] = bytes.fromhex(r)
with open(p, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
PY
fi

echo "[4/4] Kiểm định cấu hình & dọn dẹp file ẩn FAT32..."
plutil -lint "$DST_MNT/EFI/OC/config.plist" >/dev/null
"$REPO_DIR/tools/ocvalidate/ocvalidate" "$DST_MNT/EFI/OC/config.plist"
dot_clean -m "$DST_MNT/EFI" 2>/dev/null || true
sync

echo "=================================================================="
echo "[HOÀN TẤT] Đã cài đặt OpenCore lên ổ cứng NVMe (/dev/$TARGET_ESP)!"
echo "- Bạn có thể rút USB cài đặt ra khỏi máy."
echo "- Khi bật máy, vào BIOS đặt ưu tiên Boot Option #1 là 'UEFI OS / OpenCore'"
echo "  (trên ổ NVMe) để màn hình OpenCanopy 4K luôn hiện cả macOS lẫn Windows 11!"
echo "=================================================================="
