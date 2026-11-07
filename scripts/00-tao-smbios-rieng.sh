#!/bin/bash
# ==============================================================================
# BƯỚC 00: TẠO BỘ ĐỊNH DANH SMBIOS RIÊNG (MacPro7,1) — BẢO VỆ APPLE ID / iMESSAGE
# Tuyệt đối KHÔNG dùng chung Serial/MLB/UUID mặc định trên GitHub khi đăng nhập iCloud!
# Script này dùng công cụ chính hãng macserial (OpenCore 1.0.9) đi kèm trong repo
# để sinh bộ SerialNumber, MLB, SystemUUID và ROM duy nhất cho riêng máy bạn.
#
# Cách chạy:
#   1. Ghi vào bộ EFI trong thư mục repo (trước khi chép ra USB / ổ cứng):
#      bash scripts/00-tao-smbios-rieng.sh
#   2. Hoặc ghi trực tiếp vào phân vùng OpenCore EFI đang chạy trên máy:
#      sudo bash scripts/00-tao-smbios-rieng.sh --apply-efi
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OS_NAME="$(uname -s)"

if [ "$OS_NAME" = "Darwin" ]; then
  MACSERIAL="$REPO_DIR/tools/macserial/macserial"
  OCVALIDATE="$REPO_DIR/tools/ocvalidate/ocvalidate"
elif [ "$OS_NAME" = "Linux" ]; then
  MACSERIAL="$REPO_DIR/tools/macserial/macserial.linux"
  OCVALIDATE="$REPO_DIR/tools/ocvalidate/ocvalidate.linux"
else
  echo "[LỖI] Trên Windows, hãy chạy tools\\macserial\\macserial.exe -m MacPro7,1 -n 1"
  exit 1
fi

APPLY_EFI=0
if [ "${1:-}" = "--apply-efi" ]; then
  APPLY_EFI=1
  if [ "$(id -u)" -ne 0 ]; then
    echo "Vui lòng chạy với sudo khi dùng --apply-efi:"
    echo "  sudo bash scripts/00-tao-smbios-rieng.sh --apply-efi"
    exit 1
  fi
fi

TARGET_CFG="$REPO_DIR/EFI/OC/config.plist"
MNT=""

cleanup() {
  if [ -n "$MNT" ]; then
    diskutil unmount "$MNT" >/dev/null 2>&1 || true
    rmdir "$MNT" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if [ "$APPLY_EFI" -eq 1 ]; then
  MNT="/private/tmp/oc_efi_smbios"
  mkdir -p "$MNT"
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
  cp -f "$MNT/EFI/OC/config.plist" "$MNT/EFI/OC/config.plist.bak-smbios"
  TARGET_CFG="$MNT/EFI/OC/config.plist"
  echo "[OK] Đã mount phân vùng EFI (/dev/$EFI_DEV)"
fi

GEN_LINE=$("$MACSERIAL" -m MacPro7,1 -n 1 | head -n 1)
SERIAL=$(printf '%s' "$GEN_LINE" | awk -F' \\| ' '{gsub(/[[:space:]]/, "", $1); print $1}')
MLB=$(printf '%s' "$GEN_LINE" | awk -F' \\| ' '{gsub(/[[:space:]]/, "", $2); print $2}')
UUID=$(uuidgen | tr '[:lower:]' '[:upper:]')

# Lấy MAC thật của cổng Ethernet en0 nếu có (chuẩn Apple iMessage), nếu không tạo MAC ngẫu nhiên hợp lệ
ROM_HEX=""
if command -v ifconfig >/dev/null 2>&1; then
  ROM_HEX=$(ifconfig en0 2>/dev/null | awk '/ether /{gsub(/:/, "", $2); print toupper($2)}' | head -n 1 || true)
fi
if [ "${#ROM_HEX}" -ne 12 ]; then
  ROM_HEX=$(python3 -c 'import secrets; b=bytearray(secrets.token_bytes(6)); b[0]=(b[0]&0xFE)|0x02; print(b.hex().upper())')
fi

python3 - "$TARGET_CFG" "$SERIAL" "$MLB" "$UUID" "$ROM_HEX" <<'PY'
import plistlib, sys

cfg_path, serial, mlb, suuid, rom_hex = sys.argv[1:6]
with open(cfg_path, "rb") as f:
    cfg = plistlib.load(f)

gen = cfg["PlatformInfo"]["Generic"]
gen["SystemProductName"] = "MacPro7,1"
gen["SystemSerialNumber"] = serial
gen["MLB"] = mlb
gen["SystemUUID"] = suuid
gen["ROM"] = bytes.fromhex(rom_hex)

with open(cfg_path, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
PY

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$TARGET_CFG" >/dev/null
fi
"$OCVALIDATE" "$TARGET_CFG"

echo "=================================================================="
echo "[HOÀN TẤT] Đã khởi tạo bộ SMBIOS MacPro7,1 riêng cho máy của bạn!"
echo "  Tệp cập nhật       : $TARGET_CFG"
echo "  SystemProductName  : MacPro7,1"
echo "  SystemSerialNumber : $SERIAL"
echo "  MLB (Board Serial) : $MLB"
echo "  SystemUUID         : $UUID"
echo "  ROM (MAC Hex)      : $ROM_HEX"
echo "=================================================================="
