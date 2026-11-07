#!/bin/bash
# ==============================================================================
# BƯỚC 02: CÀI ĐẶT DRIVER NVIDIA RTX 3060 (PROJECT 1401 / NULLMOTH v2.7.2+) TRÊN TAHOE 26
# - Cài ứng dụng 1401.app vào /Applications và cài gói driver NullMoth (Metal 3 + Audio)
# - Mở khóa chặn IONDRVSupport cho Darwin 25.x trên EFI để xuất hình chuẩn xác
# - Dọn gọn các tác vụ nền của NullMoth (gắn AssociatedBundleIdentifiers com.nullmoth.1401
#   để không hiện các mục 'bash - Item from unidentified developer' trong System Settings)
#
# Cách chạy:
#   sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh /duong/dan/thu-muc-chua-nullmoth
#   (Thư mục đó chứa file 1401-Mac-*.dmg và nullmoth-nvidia-*.tar.gz)
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy với quyền sudo:"
  echo "  sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh /duong/dan/thu-muc-nullmoth"
  exit 1
fi

PKG_DIR="${1:-}"
if [ -z "$PKG_DIR" ]; then
  for cand in "$HOME/Downloads" "$HOME/Desktop"; do
    if ls "$cand"/nullmoth-nvidia-*.tar.gz >/dev/null 2>&1; then
      PKG_DIR="$cand"
      break
    fi
  done
fi

if [ -z "$PKG_DIR" ] || ! ls "$PKG_DIR"/nullmoth-nvidia-*.tar.gz >/dev/null 2>&1; then
  echo "[LỖI] Không tìm thấy gói nullmoth-nvidia-*.tar.gz!"
  echo "Hãy truyền đường dẫn thư mục chứa bộ cài Project 1401 / NullMoth:"
  echo "  sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh ~/Downloads"
  exit 1
fi

NV_TAR=$(ls -1t "$PKG_DIR"/nullmoth-nvidia-*.tar.gz | head -n 1)
NM_DMG=$(ls -1t "$PKG_DIR"/1401-Mac-*.dmg 2>/dev/null | head -n 1 || true)

echo "[1/4] Cài ứng dụng quản lý 1401.app vào /Applications..."
if [ -n "$NM_DMG" ]; then
  NM_MNT="/private/tmp/nm1401_mnt"
  mkdir -p "$NM_MNT"
  hdiutil attach -nobrowse -readonly -mountpoint "$NM_MNT" "$NM_DMG" >/dev/null 2>&1 || true
  APP_FOUND=$(find "$NM_MNT" -maxdepth 2 -name "*.app" -print -quit 2>/dev/null || true)
  if [ -n "$APP_FOUND" ]; then
    APP_NAME=$(basename "$APP_FOUND")
    rm -rf "/Applications/$APP_NAME"
    cp -R "$APP_FOUND" "/Applications/$APP_NAME"
    xattr -cr "/Applications/$APP_NAME" 2>/dev/null || true
    echo "    [OK] Đã cài /Applications/$APP_NAME"
  fi
  hdiutil detach "$NM_MNT" >/dev/null 2>&1 || true
  rmdir "$NM_MNT" 2>/dev/null || true
fi

echo "[2/4] Giải nén & cài đặt gói driver RTX 3060: $(basename "$NV_TAR")..."
TMP_NV="/private/tmp/nullmoth-install"
rm -rf "$TMP_NV"
mkdir -p "$TMP_NV"
tar -zxf "$NV_TAR" -C "$TMP_NV"
if [ -x "$TMP_NV/pkgroot/install.sh" ]; then
  (cd "$TMP_NV/pkgroot" && /bin/bash ./install.sh)
  echo "    [OK] Đã cài xong Driver NVIDIA RTX 3060 (Metal 3 + HDMI/DP Audio + ALC897)!"
else
  rm -rf "$TMP_NV"
  echo "[LỖI] Không tìm thấy pkgroot/install.sh bên trong $NV_TAR"
  exit 1
fi
rm -rf "$TMP_NV"

echo "[3/4] Đảm bảo chặn IONDRVSupport trên EFI áp dụng cho cả macOS Tahoe 26..."
MNT="/private/tmp/oc_efi_nv"
mkdir -p "$MNT"
for part in $(diskutil list internal | awk '/EFI/{print $NF}'); do
  if diskutil mount -mountPoint "$MNT" "/dev/$part" >/dev/null 2>&1; then
    if [ -f "$MNT/EFI/OC/config.plist" ]; then
      python3 - "$MNT/EFI/OC/config.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
with open(p, "rb") as f:
    cfg = plistlib.load(f)
for blk in cfg["Kernel"].get("Block", []):
    if blk.get("Identifier") == "com.apple.iokit.IONDRVSupport":
        blk["Enabled"] = True
        blk["MaxKernel"] = ""
with open(p, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
PY
      plutil -lint "$MNT/EFI/OC/config.plist" >/dev/null
      dot_clean -m "$MNT/EFI" 2>/dev/null || true
      sync
      diskutil unmount "$MNT" >/dev/null 2>&1 || true
      break
    fi
    diskutil unmount "$MNT" >/dev/null 2>&1 || true
  fi
done
rmdir "$MNT" 2>/dev/null || true

echo "[4/4] Gom nhóm sạch các tác vụ nền của NullMoth dưới ứng dụng 1401.app..."
for item in com.nullmoth.bootguard com.nullmoth.recover; do
  plist="/Library/LaunchDaemons/${item}.plist"
  if [ -f "$plist" ]; then
    launchctl bootout "system/${item}" 2>/dev/null || true
    python3 - "$plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
with open(p, "rb") as f:
    d = plistlib.load(f)
d["AssociatedBundleIdentifiers"] = ["com.nullmoth.1401"]
with open(p, "wb") as f:
    plistlib.dump(d, f, sort_keys=False)
PY
    chown root:wheel "$plist"
    chmod 644 "$plist"
    plutil -lint "$plist" >/dev/null
    launchctl bootstrap system "$plist" 2>/dev/null || true
  fi
done

echo "=================================================================="
echo "[HOÀN TẤT] Đã cài đặt Driver RTX 3060 trên macOS Tahoe!"
echo "- Mở System Settings -> Privacy & Security bấm Allow nếu được hỏi."
echo "- Khởi động lại máy để kích hoạt đầy đủ Metal 3 + Âm thanh."
echo "- Sau khi ổn định, nếu xuất hiện mục com.nullmoth.lastgood một lần,"
echo "  có thể chạy lại script này hoặc gỡ com.nullmoth.lastgood cho gọn."
echo "=================================================================="
