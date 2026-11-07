#!/bin/bash
# ==============================================================================
# BƯỚC 02: CÀI ĐẶT DRIVER NVIDIA RTX 3060 (PROJECT 1401 / NULLMOTH) TRÊN TAHOE 26
# - Hỗ trợ TỰ ĐỘNG TẢI gói chính thức mới nhất từ GitHub NullMoth (kèm kiểm tra SHA-256)
#   nếu bạn chưa tải sẵn, HOẶC cài Offline ngay từ USB / ~/Downloads!
# - Cài ứng dụng 1401.app vào /Applications & gói driver NullMoth (Metal 3 + Audio)
# - Tự động nâng cấp OpenCore EFI từ Stage-1 (cài mới) lên Stage-2 hoàn chỉnh:
#   + Gỡ -nvoff, bổ sung đầy đủ cờ chống lỗi "màn hình đen chỉ hiện con trỏ chuột"
#   + Bật chặn com.apple.iokit.IONDRVSupport cho cả Darwin 25.x (Tahoe 26)
# - Gom gọn các tác vụ nền dưới 1401.app (không hiện mục 'bash' lạ trong Login Items)
#
# Cách chạy:
#   sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh [đường_dẫn_thư_mục_chứa_nullmoth]
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy với quyền sudo:"
  echo "  sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONSOLE_USER=$(stat -f %Su /dev/console 2>/dev/null || echo "")
USER_HOME="$HOME"
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ] && [ -d "/Users/$CONSOLE_USER" ]; then
  USER_HOME="/Users/$CONSOLE_USER"
fi

PKG_DIR="${1:-}"
if [ -z "$PKG_DIR" ]; then
  for cand in \
    "$USER_HOME/Downloads" \
    "$USER_HOME/Desktop" \
    "$REPO_DIR" \
    /Volumes/*/HACKINTOSH-TOOLS \
    /Volumes/*; do
    if [ -d "$cand" ] && ls "$cand"/nullmoth-nvidia-*.tar.gz >/dev/null 2>&1; then
      PKG_DIR="$cand"
      break
    fi
  done
fi

# Nếu chưa có gói cài sẵn -> Tự động tải từ GitHub chính thức của NullMoth + kiểm tra SHA-256!
if [ -z "$PKG_DIR" ] || ! ls "$PKG_DIR"/nullmoth-nvidia-*.tar.gz >/dev/null 2>&1; then
  echo "=================================================================="
  echo "Chưa tìm thấy gói nullmoth-nvidia-*.tar.gz có sẵn trên máy/USB."
  echo "Đang tự động tải bản phát hành chính thức mới nhất từ NullMoth GitHub:"
  echo "  -> https://github.com/nullmoth/nvidia-macos-driver/releases/latest"
  echo "=================================================================="

  DL_DIR="$USER_HOME/Downloads/NullMoth-Official"
  mkdir -p "$DL_DIR"

  META_JSON=$(curl -fsSL "https://api.github.com/repos/nullmoth/nvidia-macos-driver/releases/latest")
  read -r TAG_NAME TAR_URL TAR_NAME DMG_URL DMG_NAME SHA_URL < <(
    python3 -c '
import json, sys
d = json.loads(sys.stdin.read())
tag = d.get("tag_name", "latest")
tar_u = tar_n = dmg_u = dmg_n = sha_u = ""
for a in d.get("assets", []):
    n = a.get("name", "")
    u = a.get("browser_download_url", "")
    if n.startswith("nullmoth-nvidia-") and n.endswith(".tar.gz"):
        tar_u, tar_n = u, n
    elif n.startswith("1401-Mac-") and n.endswith(".dmg"):
        dmg_u, dmg_n = u, n
    elif n == "SHA256SUMS.txt":
        sha_u = u
print(tag, tar_u, tar_n, dmg_u, dmg_n, sha_u)
' <<< "$META_JSON"
  )

  if [ -z "$TAR_URL" ]; then
    echo "[LỖI] Không đọc được link tải từ GitHub! Bạn có thể tự tải thủ công 2 file:"
    echo "  1) 1401-Mac-*.dmg"
    echo "  2) nullmoth-nvidia-*.tar.gz"
    echo "tại: https://github.com/nullmoth/nvidia-macos-driver/releases/latest"
    echo "rồi bỏ vào ~/Downloads và chạy lại script này."
    exit 1
  fi

  echo "  Phiên bản phát hiện: $TAG_NAME"
  if [ -n "$SHA_URL" ]; then
    curl -fL "$SHA_URL" -o "$DL_DIR/SHA256SUMS.txt"
  fi
  if [ -n "$DMG_URL" ]; then
    echo "  Đang tải $DMG_NAME..."
    curl -fL --progress-bar "$DMG_URL" -o "$DL_DIR/$DMG_NAME"
  fi
  echo "  Đang tải $TAR_NAME (~255 MB)..."
  curl -fL --progress-bar "$TAR_URL" -o "$DL_DIR/$TAR_NAME"

  if [ -f "$DL_DIR/SHA256SUMS.txt" ]; then
    echo "  Đang kiểm tra toàn vẹn mã băm SHA-256..."
    EXPECTED_TAR=$(awk -v f="$TAR_NAME" '$2 == f || $2 == "*"f {print $1; exit}' "$DL_DIR/SHA256SUMS.txt")
    ACTUAL_TAR=$(shasum -a 256 "$DL_DIR/$TAR_NAME" | awk '{print $1}')
    if [ -n "$EXPECTED_TAR" ] && [ "$EXPECTED_TAR" != "$ACTUAL_TAR" ]; then
      echo "[LỖI] Sai lệch SHA-256 trên $TAR_NAME! Hủy cài đặt để đảm bảo an toàn."
      exit 1
    fi
    echo "  [OK] Xác thực SHA-256 hợp lệ 100%!"
  fi

  chown -R "${CONSOLE_USER:-root}:staff" "$DL_DIR" 2>/dev/null || true
  PKG_DIR="$DL_DIR"
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
  echo "    [OK] Đã cài xong Driver NVIDIA (Metal 3 + HDMI/DP Audio + ALC897)!"
else
  rm -rf "$TMP_NV"
  echo "[LỖI] Không tìm thấy pkgroot/install.sh bên trong $NV_TAR"
  exit 1
fi
rm -rf "$TMP_NV"

# Phát hiện GPU Turing (GTX 16xx / RTX 20xx) để tự động thêm nvrmsettle=10000 nếu cần
IS_TURING=0
NV_DEVID=$(ioreg -r -c IOPCIDevice -l -w0 2>/dev/null | LC_ALL=C awk '
  /\+-o / { if (v && d != "") { print substr(d,3,2) substr(d,1,2); exit }; v=0; d="" }
  /"vendor-id" = <de100000>/ { v=1 }
  /"device-id" = </ { if (match($0, /<[0-9a-f]+>/)) d=substr($0, RSTART+1, 4) }
  END { if (v && d != "") print substr(d,3,2) substr(d,1,2) }
' || true)
case "$NV_DEVID" in
  1[eEfF]??|21[89a-fA-F]?) IS_TURING=1 ;;
esac

echo "[3/4] Chuyển OpenCore EFI sang Stage-2 (gỡ -nvoff, bật đủ cờ chống màn hình đen & chặn IONDRVSupport)..."
MNT="/private/tmp/oc_efi_nv"
mkdir -p "$MNT"
UPDATED_ANY=0

for part in $(diskutil list | awk '/EFI/{print $NF}'); do
  if diskutil mount -mountPoint "$MNT" "/dev/$part" >/dev/null 2>&1; then
    if [ -f "$MNT/EFI/OC/config.plist" ]; then
      cp -f "$MNT/EFI/OC/config.plist" "$MNT/EFI/OC/config.plist.bak-stage2"
      python3 - "$MNT/EFI/OC/config.plist" "$IS_TURING" <<'PY'
import plistlib, sys

p = sys.argv[1]
is_turing = sys.argv[2] == "1"

with open(p, "rb") as f:
    cfg = plistlib.load(f)

# 1. Block IONDRVSupport across all kernels including Tahoe 26 (Darwin 25)
found_block = False
for blk in cfg["Kernel"].setdefault("Block", []):
    if blk.get("Identifier") == "com.apple.iokit.IONDRVSupport":
        blk["Enabled"] = True
        blk["MaxKernel"] = ""
        found_block = True
if not found_block:
    cfg["Kernel"]["Block"].append({
        "Arch": "Any",
        "Comment": "boot framebuffer IONDRVFramebuffer steals index 0 from NVRMFB",
        "Enabled": True,
        "Identifier": "com.apple.iokit.IONDRVSupport",
        "MaxKernel": "",
        "MinKernel": "",
        "Strategy": "Exclude",
    })

# 2. Ensure Lilu & AMFIPass are enabled
for kx in cfg["Kernel"].get("Add", []):
    if kx.get("BundlePath") in ("Lilu.kext", "AMFIPass.kext", "WhateverGreen.kext"):
        kx["Enabled"] = True

# 3. Ensure Algrey Fix PAT is on and Shaneee Fix PAT is off on AMD
for pt in cfg["Kernel"].get("Patch", []):
    cm = pt.get("Comment", "")
    if "fix pat" in cm.lower():
        if "shaneee" in cm.lower():
            pt["Enabled"] = False
        elif "algrey" in cm.lower():
            pt["Enabled"] = True

# 4. Update boot-args (remove -nvoff / nv_disable=1 / -wegnoegpu, enforce anti-black-screen flags)
nv_uuid = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
nv_add = cfg["NVRAM"]["Add"][nv_uuid]
cur_tokens = nv_add.get("boot-args", "").split()
drop = {"-nvoff", "nv_disable=1", "-wegnoegpu"}
tokens = [t for t in cur_tokens if t not in drop]

required = [
    "debug=0x100",
    "keepsyms=1",
    "-lilubetaall",
    "nvfb=1",
    "nvaccel=1",
    "nvfbheads=4",
    "-nvkmsnosmooth",
    "amfi_get_out_of_my_way=0x1",
    "amfi=0x80",
    "ipc_control_port_options=0",
    "gfxrst=4",
]
if is_turing and not any(t.startswith("nvrmsettle=") for t in tokens):
    required.append("nvrmsettle=10000")

for req in required:
    if req not in tokens:
        tokens.append(req)

nv_add["boot-args"] = " ".join(tokens)
nv_add["csr-active-config"] = bytes.fromhex("430a0000")
cfg["Misc"]["Security"]["SecureBootModel"] = "Disabled"

with open(p, "wb") as f:
    plistlib.dump(cfg, f, sort_keys=False)
PY
      plutil -lint "$MNT/EFI/OC/config.plist" >/dev/null
      if [ -x "$REPO_DIR/tools/ocvalidate/ocvalidate" ]; then
        "$REPO_DIR/tools/ocvalidate/ocvalidate" "$MNT/EFI/OC/config.plist" >/dev/null
      fi
      NEW_ARGS=$(plutil -extract "NVRAM.Add.7C436110-AB2A-4BBB-A880-FE41995C9F82.boot-args" raw -o - "$MNT/EFI/OC/config.plist")
      nvram boot-args="$NEW_ARGS" 2>/dev/null || true
      dot_clean -m "$MNT/EFI" 2>/dev/null || true
      sync
      UPDATED_ANY=1
      echo "    [OK] Đã nâng cấp Stage-2 cho phân vùng OpenCore (/dev/$part)"
    fi
    diskutil unmount "$MNT" >/dev/null 2>&1 || true
  fi
done
rmdir "$MNT" 2>/dev/null || true

if [ "$UPDATED_ANY" -eq 0 ]; then
  echo "    [CẢNH BÁO] Không tìm thấy phân vùng EFI chứa OpenCore để cập nhật tự động!"
fi

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
echo "[HOÀN TẤT] Đã cài đặt Driver RTX 3060 & chuyển EFI lên Stage-2!"
echo "- Mở System Settings -> Privacy & Security bấm Allow nếu được hỏi."
echo "- Khởi động lại máy 1 lần để kích hoạt đầy đủ Metal 3 + Âm thanh."
echo "- Nếu cài mới từ USB, sau khi vào lại macOS hãy chạy tiếp Bước 03, 05 và 10!"
echo "=================================================================="
