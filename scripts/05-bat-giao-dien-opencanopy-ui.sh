#!/bin/bash
# ==============================================================================
# BƯỚC 05: BẬT GIAO DIỆN ĐỒ HỌA CHỌN HỆ ĐIỀU HÀNH (OPENCANOPY 4K) & TẮT LOG BOOT
# - Bật giao diện đồ họa GoldenGate 4K hỗ trợ chuột + phím tắt
# - Ẩn gọn Recovery / Reset NVRAM / 1401 (bấm phím Space / Phím Cách mới hiện)
# - Tắt toàn bộ chữ log đen trắng [OC] và '-v' -> vào macOS hiện thẳng Logo Táo
# - Giữ nguyên 100% tương thích NullMoth RTX 3060 (1401.app) & khóa macOS mặc định
#
# Cách chạy:
#   sudo bash scripts/05-bat-giao-dien-opencanopy-ui.sh
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy với quyền sudo:"
  echo "  sudo bash scripts/05-bat-giao-dien-opencanopy-ui.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_CANOPY="$REPO_DIR/EFI/OC/Drivers/OpenCanopy.efi"
SRC_RES="$REPO_DIR/EFI/OC/Resources"
SRC_OC="$REPO_DIR/EFI/OC/OpenCore.efi"
OCVALIDATE="$REPO_DIR/tools/ocvalidate/ocvalidate"
TS=$(date +"%Y%m%d-%H%M%S")

EXPECTED_OC_SHA=$(shasum -a 256 "$SRC_OC" | awk '{print $1}')
EXPECTED_CANOPY_SHA=$(shasum -a 256 "$SRC_CANOPY" | awk '{print $1}')

MNT="/private/tmp/oc_efi_ui"
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

LIVE_OC_SHA=$(shasum -a 256 "$MNT/EFI/OC/OpenCore.efi" | awk '{print $1}')
if [ "$LIVE_OC_SHA" != "$EXPECTED_OC_SHA" ]; then
  echo "[LỖI] Phiên bản OpenCore.efi trên EFI khác với bản OpenCore 1.0.9 của repo!"
  echo "Hãy đồng bộ toàn bộ BOOTx64.efi + OpenCore.efi + Drivers từ cùng một bản build trước."
  exit 1
fi

cp -f "$MNT/EFI/OC/config.plist" "$MNT/EFI/OC/config.plist.before-opencanopy-ui"

if [ ! -f "$MNT/EFI/OC/Resources/Image/Acidanthera/GoldenGate/Background.icns" ]; then
  echo "[1/3] Chép bộ tài nguyên giao diện 4K GoldenGate vào EFI/OC/Resources..."
  mkdir -p "$MNT/EFI/OC/Resources"
  cp -R "$SRC_RES/"* "$MNT/EFI/OC/Resources/"
fi

echo "[2/3] Cài đặt OpenCanopy.efi & cấu hình giao diện + tắt log verbose (-v)..."
cp -f "$SRC_CANOPY" "$MNT/EFI/OC/Drivers/OpenCanopy.efi"
chmod 644 "$MNT/EFI/OC/Drivers/OpenCanopy.efi"
xattr -c "$MNT/EFI/OC/Drivers/OpenCanopy.efi" 2>/dev/null || true

INST_CANOPY_SHA=$(shasum -a 256 "$MNT/EFI/OC/Drivers/OpenCanopy.efi" | awk '{print $1}')
if [ "$INST_CANOPY_SHA" != "$EXPECTED_CANOPY_SHA" ]; then
  echo "[LỖI] SHA-256 OpenCanopy.efi trên EFI không khớp!"
  cp -f "$MNT/EFI/OC/config.plist.before-opencanopy-ui" "$MNT/EFI/OC/config.plist"
  exit 1
fi

NEW_BOOT_ARGS=$(python3 - "$MNT/EFI/OC/config.plist" <<'PY'
import plistlib, sys

cfg_path = sys.argv[1]
with open(cfg_path, "rb") as f:
    cfg = plistlib.load(f)

boot = cfg["Misc"]["Boot"]
boot["PickerMode"] = "External"
boot["PickerVariant"] = "Acidanthera\\GoldenGate"
boot["PickerAttributes"] = 145
boot["ShowPicker"] = True
boot["HideAuxiliary"] = True
boot["PollAppleHotKeys"] = True

dbg = cfg["Misc"]["Debug"]
dbg["AppleDebug"] = False
dbg["Target"] = (int(dbg.get("Target", 67)) & ~1) | 66

for tool in cfg["Misc"].get("Tools", []):
    if tool.get("Path") == "NullMothSafe.efi":
        tool["Auxiliary"] = True

drivers = cfg["UEFI"]["Drivers"]
found = False
for drv in drivers:
    if isinstance(drv, dict) and drv.get("Path") == "OpenCanopy.efi":
        drv["Enabled"] = True
        drv["LoadEarly"] = False
        drv["Arguments"] = ""
        drv["HideVerbose"] = True
        found = True
        break
if not found:
    drivers.append({
        "Arguments": "",
        "Comment": "OpenCanopy Graphical Boot Picker",
        "Enabled": True,
        "HideVerbose": True,
        "LoadEarly": False,
        "Path": "OpenCanopy.efi",
    })

apple_guid = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
nv_add = cfg["NVRAM"]["Add"][apple_guid]
tokens = [t for t in nv_add.get("boot-args", "").split() if t != "-v"]
new_args = " ".join(tokens)
nv_add["boot-args"] = new_args

with open(cfg_path, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)

print(new_args)
PY
)

plutil -lint "$MNT/EFI/OC/config.plist" >/dev/null
if [ -x "$OCVALIDATE" ]; then
  OCV_OUT=$("$OCVALIDATE" "$MNT/EFI/OC/config.plist" 2>&1 || true)
  if ! printf '%s\n' "$OCV_OUT" | grep "No issues found." >/dev/null; then
    echo "[LỖI] ocvalidate phát hiện lỗi cấu hình:"
    printf '%s\n' "$OCV_OUT"
    cp -f "$MNT/EFI/OC/config.plist.before-opencanopy-ui" "$MNT/EFI/OC/config.plist"
    exit 1
  fi
fi

dot_clean -m "$MNT/EFI" 2>/dev/null || true
sync
diskutil unmount "$MNT" >/dev/null 2>&1 || true
rmdir "$MNT" 2>/dev/null || true

echo "[3/3] Đồng bộ NVRAM boot-args & đặt macOS làm Hệ điều hành mặc định..."
nvram boot-args="$NEW_BOOT_ARGS" 2>/dev/null || true
VOL_GRP=$(diskutil info / | awk -F': *' '/APFS Volume Group/{print $2}' | tr -d ' ')
OCBT_DECODED=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:OCBt0080 2>/dev/null | sed 's/%00//g' || true)
if [ -n "$VOL_GRP" ] && printf '%s\n' "$OCBT_DECODED" | grep -i "$VOL_GRP" >/dev/null; then
  echo "    [OK] macOS đã là Hệ điều hành mặc định (tự khởi động sau 5 giây)."
else
  bless --mount / --setBoot >/dev/null 2>&1 || true
  echo "    [OK] Đã khóa macOS làm Hệ điều hành mặc định (tự khởi động sau 5 giây)."
fi

echo "=================================================================="
echo "[HOÀN TẤT] Đã bật giao diện OpenCanopy 4K & tắt chữ log verbose!"
echo "  - Click chuột hoặc dùng phím mũi tên + Enter để chọn HĐH"
echo "  - Giữ Ctrl + Enter để đổi HĐH mặc định"
echo "  - Nhấn phím Space (Phím Cách) để hiện Recovery / Reset NVRAM / 1401"
echo "  - Giữ Cmd/Win + V khi chọn macOS nếu muốn xem log tạm thời 1 lần"
echo "=================================================================="
