#!/bin/bash
# ==============================================================================
# BƯỚC 00: TẠO BỘ ĐỊNH DANH SMBIOS RIÊNG (MacPro7,1) — BẢO VỆ APPLE ID / iMESSAGE
# Tuyệt đối KHÔNG dùng chung Serial/MLB/UUID mặc định trên GitHub khi đăng nhập iCloud!
#
# Cách chạy:
#   1. Tạo SMBIOS cho bộ EFI trong repo (mặc định giữ cấu hình hiện tại):
#      bash scripts/00-tao-smbios-rieng.sh
#   2. Tạo bộ EFI STAGE-1 để chép ra USB cài mới từ đầu (mở IONDRVSupport, thêm -nvoff -v):
#      bash scripts/00-tao-smbios-rieng.sh --stage1 [--cores 6]
#   3. Ghi trực tiếp SMBIOS mới vào phân vùng OpenCore EFI đang chạy trên ổ cứng:
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
  echo "[LỖI] Trên Windows, hãy đúp chuột chạy: scripts\\windows\\02-chuan-bi-efi-cai-moi-windows.cmd"
  exit 1
fi

APPLY_EFI=0
USE_STAGE1=0
CORES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --apply-efi) APPLY_EFI=1 ;;
    --stage1)    USE_STAGE1=1 ;;
    --cores)     CORES="${2:-}"; shift ;;
    *)
      echo "Tham số không hợp lệ: $1"
      echo "Cách dùng: bash scripts/00-tao-smbios-rieng.sh [--stage1] [--cores 6|8|12|16] [--apply-efi]"
      exit 1
      ;;
  esac
  shift
done

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
  if [ "$(id -u)" -ne 0 ]; then
    echo "Vui lòng chạy với sudo khi dùng --apply-efi:"
    echo "  sudo bash scripts/00-tao-smbios-rieng.sh --apply-efi"
    exit 1
  fi
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
elif [ "$USE_STAGE1" -eq 1 ]; then
  cp -f "$REPO_DIR/EFI/OC/config-stage1-cai-moi.plist" "$TARGET_CFG"
  echo "[OK] Đã nạp cấu hình STAGE 1 (Cài mới từ USB — mở IONDRVSupport, bật -v -nvoff)"
fi

GEN_LINE=$("$MACSERIAL" -m MacPro7,1 -n 1 | head -n 1)
SERIAL=$(printf '%s' "$GEN_LINE" | awk -F' \\| ' '{gsub(/[[:space:]]/, "", $1); print $1}')
MLB=$(printf '%s' "$GEN_LINE" | awk -F' \\| ' '{gsub(/[[:space:]]/, "", $2); print $2}')
UUID=$(uuidgen | tr '[:lower:]' '[:upper:]')

ROM_HEX=""
if command -v ifconfig >/dev/null 2>&1; then
  ROM_HEX=$(ifconfig en0 2>/dev/null | awk '/ether /{gsub(/:/, "", $2); print toupper($2)}' | head -n 1 || true)
fi
if [ "${#ROM_HEX}" -ne 12 ]; then
  ROM_HEX=$(python3 -c 'import secrets; b=bytearray(secrets.token_bytes(6)); b[0]=(b[0]&0xFE)|0x02; print(b.hex().upper())')
fi

python3 - "$TARGET_CFG" "$SERIAL" "$MLB" "$UUID" "$ROM_HEX" "$CORES" <<'PY'
import plistlib, sys

cfg_path, serial, mlb, suuid, rom_hex, cores_str = sys.argv[1:7]
with open(cfg_path, "rb") as f:
    cfg = plistlib.load(f)

gen = cfg["PlatformInfo"]["Generic"]
gen["SystemProductName"] = "MacPro7,1"
gen["SystemSerialNumber"] = serial
gen["MLB"] = mlb
gen["SystemUUID"] = suuid
gen["ROM"] = bytes.fromhex(rom_hex)

if cores_str:
    c = int(cores_str)
    if not (2 <= c <= 64):
        raise ValueError(f"Invalid core count: {c}")
    for pt in cfg["Kernel"].get("Patch", []):
        cm = pt.get("Comment", "")
        if "Force cpuid_cores_per_package" in cm:
            if "10.13-10.14" in cm:
                pt["Replace"] = bytes([0xB8, c, 0, 0, 0, 0])
            elif "10.15-11.0" in cm:
                pt["Replace"] = bytes([0xBA, c, 0, 0, 0, 0])
            elif "12.0-13.2" in cm:
                pt["Replace"] = bytes([0xBA, c, 0, 0, 0, 0x90])
            elif "13.3+" in cm:
                pt["Replace"] = bytes([0xBA, c, 0, 0, 0])

with open(cfg_path, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
PY

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$TARGET_CFG" >/dev/null
fi
if [ "$APPLY_EFI" -eq 1 ] && command -v dot_clean >/dev/null 2>&1; then
  dot_clean -m "$MNT/EFI" 2>/dev/null || true
  sync
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
[ -n "$CORES" ] && echo "  AMD CPU Cores      : $CORES nhân vật lý"
echo "=================================================================="
