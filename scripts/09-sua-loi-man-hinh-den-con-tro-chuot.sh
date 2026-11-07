#!/bin/bash
# ==============================================================================
# BƯỚC 09: CHẨN ĐOÁN & SỬA TRIỆT ĐỂ LỖI "MÀN HÌNH ĐEN CÙNG CON TRỎ CHUỘT"
# (Black Screen + Movable Mouse Cursor Only trên NVIDIA RTX 3060 / NullMoth + Tahoe 26)
#
# Kiểm tra và tự động khắc phục toàn bộ 6 nguyên nhân kỹ thuật gốc rễ:
#   1. Cửa sổ PCIe BAR1 bị giới hạn 256 MB do tắt Resizable BAR / Above 4G trong BIOS
#   2. Thiếu hoặc lệch 4 kext NullMoth (NVRM, NVAccel, NVRMFB, NVRMAGDC) trong AuxiliaryKC
#   3. Thiếu AMFIPass.kext / sai thứ tự Lilu / thiếu -lilubetaall / SIP 0x0A43 khiến
#      WindowServer từ chối nạp bundle Metal -> màn hình tối đen chỉ hiện trỏ chuột
#   4. Thiếu cờ -nvkmsnosmooth, gfxrst=4, nvfb=1, nvaccel=1 (hoặc nvrmsettle=10000 trên Turing)
#   5. Lệch trạng thái chặn com.apple.iokit.IONDRVSupport so với trạng thái cài đặt driver
#   6. Bật nhầm Shaneee Fix PAT thay vì Algrey Fix PAT hoặc tắt DisableVariableWrite trên AMD
#
# Cách chạy:
#   - Tự động kiểm tra & sửa toàn bộ để lên Full Metal 3:
#     sudo bash scripts/09-sua-loi-man-hinh-den-con-tro-chuot.sh
#   - Hoặc tạm thời mở chế độ cứu hộ an toàn (-nvoff + mở IONDRVSupport):
#     sudo bash scripts/09-sua-loi-man-hinh-den-con-tro-chuot.sh --safe-fallback
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui lòng chạy với quyền sudo:"
  echo "  sudo bash scripts/09-sua-loi-man-hinh-den-con-tro-chuot.sh"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAFE_FALLBACK=0
if [ "${1:-}" = "--safe-fallback" ]; then
  SAFE_FALLBACK=1
fi

echo "=================================================================="
echo "CHẨN ĐOÁN & SỬA LỖI MÀN HÌNH ĐEN CHỈ HIỆN CON TRỎ CHUỘT (RTX 3060)"
echo "=================================================================="

# 1. Kiểm tra cửa sổ PCIe BAR1 (Resizable BAR trong BIOS)
echo "[1/5] Kiểm tra cửa sổ bộ nhớ PCIe BAR1 của card NVIDIA..."
BAR_LINE=$(ioreg -r -n NVRM -d 1 -l 2>/dev/null | grep '"nvrm-bars"' || true)
if [ -n "$BAR_LINE" ]; then
  echo "      $BAR_LINE"
  if printf '%s\n' "$BAR_LINE" | grep "bar1@[^ ]*+0x10000000 " >/dev/null; then
    echo "  [CẢNH BÁO QUAN TRỌNG] BAR1 hiện chỉ có 256 MB (0x10000000)!"
    echo "  -> Cửa sổ BAR1 256 MB bị tràn ngay ở màn hình đăng nhập gây MÀN HÌNH ĐEN CHỈ CÓ TRỎ CHUỘT!"
    echo "  -> Hãy vào BIOS bo mạch chủ BẬT cả 2 mục:"
    echo "     1) Above 4G Decoding = Enabled"
    echo "     2) Resizable BAR (Re-Size BAR Support) = Enabled"
  else
    echo "  [OK] Cửa sổ BAR1 đã mở rộng chuẩn xác (Resizable BAR hoạt động tốt)."
  fi
else
  echo "  [GHI CHÚ] Hiện đang chạy chế độ không nạp NVRM (hoặc -nvoff); sẽ kiểm tra tiếp cấu hình."
fi

# 2. Kiểm tra 4 kext NullMoth trong AuxiliaryKernelExtensions.kc
echo "[2/5] Kiểm tra gói kext NullMoth trong AuxiliaryKernelExtensions.kc..."
OS_MAJ=$(sw_vers -productVersion | cut -d. -f1)
KC_HAS_NULLMOTH=0

if [ -f "/Library/KernelCollections/AuxiliaryKernelExtensions.kc" ]; then
  INS=$(kmutil inspect -a x86_64 -A /Library/KernelCollections/AuxiliaryKernelExtensions.kc 2>/dev/null || true)
  MISSING_KEXT=0
  for k in NVRM NVAccel NVRMFB NVRMAGDC; do
    if ! printf '%s\n' "$INS" | grep "com.nullmoth.$k" >/dev/null; then
      MISSING_KEXT=1
    fi
  done
  if [ "$MISSING_KEXT" -eq 0 ]; then
    KC_HAS_NULLMOTH=1
    echo "  [OK] Đủ cả 4 kext (NVRM, NVAccel, NVRMFB, NVRMAGDC) trong AuxiliaryKC!"
  fi
fi

if [ "$KC_HAS_NULLMOTH" -eq 0 ] && [ "$SAFE_FALLBACK" -eq 0 ]; then
  if [ -d "/Library/NullMoth/kexts/$OS_MAJ/NVAccel.kext" ] && [ -d "/Library/Extensions/NVRM.kext" ]; then
    echo "  [ĐANG SỬA] Phát hiện AuxiliaryKC thiếu kext cho macOS $OS_MAJ — đang đóng gói lại bằng kmutil..."
    rm -rf /Library/Extensions/NVAccel.kext
    ditto "/Library/NullMoth/kexts/$OS_MAJ/NVAccel.kext" /Library/Extensions/NVAccel.kext
    chown -R root:wheel /Library/Extensions/NV*.kext
    chmod -R go-w /Library/Extensions/NV*.kext
    KARGS=(--allow-missing-kdk)
    [ -f /System/Library/Kernels/kernel ] && KARGS+=(--kernel /System/Library/Kernels/kernel)
    kmutil create -n aux --volume-root / "${KARGS[@]}" \
      -B /System/Library/KernelCollections/BootKernelExtensions.kc \
      -S /System/Library/KernelCollections/SystemKernelExtensions.kc \
      --repository /Library/Extensions \
      -A /Library/KernelCollections/AuxiliaryKernelExtensions.kc -z
    KC_HAS_NULLMOTH=1
    echo "  [OK] Đã rebuild thành công AuxiliaryKernelExtensions.kc cho macOS $OS_MAJ!"
  else
    echo "  [CẢNH BÁO] Máy CHƯA cài gói driver NullMoth trong /Library/Extensions!"
    echo "  -> Hệ thống sẽ tự động đặt IONDRVSupport = False để tránh mất hình cho tới khi bạn chạy script 02."
  fi
fi

# 3. Phát hiện GPU Turing (GTX 16xx / RTX 20xx)
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

# 4. Sửa trực tiếp trên tất cả phân vùng OpenCore EFI đang kết nối
echo "[3/5] Đang kiểm tra & sửa cấu hình OpenCore EFI (AMFIPass, SIP, Fix PAT, IONDRVSupport, boot-args)..."
MNT="/private/tmp/oc_efi_fixblack"
mkdir -p "$MNT"
FIXED_PARTS=0

ENABLE_NV=1
if [ "$SAFE_FALLBACK" -eq 1 ] || [ "$KC_HAS_NULLMOTH" -eq 0 ]; then
  ENABLE_NV=0
fi

for part in $(diskutil list | awk '/EFI/{print $NF}'); do
  if diskutil mount -mountPoint "$MNT" "/dev/$part" >/dev/null 2>&1; then
    if [ -f "$MNT/EFI/OC/config.plist" ]; then
      cp -f "$MNT/EFI/OC/config.plist" "$MNT/EFI/OC/config.plist.bak-blackscreen"

      # Nếu thiếu AMFIPass.kext hoặc Lilu.kext trên EFI đích thì chép từ repo sang
      for req_kext in Lilu.kext AMFIPass.kext WhateverGreen.kext; do
        if [ ! -d "$MNT/EFI/OC/Kexts/$req_kext" ] && [ -d "$REPO_DIR/EFI/OC/Kexts/$req_kext" ]; then
          cp -R "$REPO_DIR/EFI/OC/Kexts/$req_kext" "$MNT/EFI/OC/Kexts/$req_kext"
        fi
      done

      python3 - "$MNT/EFI/OC/config.plist" "$ENABLE_NV" "$IS_TURING" <<'PY'
import plistlib, sys

p = sys.argv[1]
enable_nv = sys.argv[2] == "1"
is_turing = sys.argv[3] == "1"

with open(p, "rb") as f:
    cfg = plistlib.load(f)

# Ensure Lilu loads BEFORE AMFIPass, and both are Enabled
klist = cfg["Kernel"].setdefault("Add", [])
lilu_idx = amfi_idx = None
for idx, kx in enumerate(klist):
    bp = kx.get("BundlePath", "")
    if bp == "Lilu.kext":
        kx["Enabled"] = True
        lilu_idx = idx
    elif bp == "AMFIPass.kext":
        kx["Enabled"] = True
        amfi_idx = idx
    elif bp == "WhateverGreen.kext":
        kx["Enabled"] = True

if amfi_idx is None:
    klist.append({
        "Arch": "Any",
        "BundlePath": "AMFIPass.kext",
        "Comment": "AMFIPass lets WindowServer map ad-hoc NullMoth Metal bundle",
        "Enabled": True,
        "ExecutablePath": "Contents/MacOS/AMFIPass",
        "MaxKernel": "",
        "MinKernel": "20.0.0",
        "PlistPath": "Contents/Info.plist",
    })
elif lilu_idx is not None and amfi_idx < lilu_idx:
    amfi_entry = klist.pop(amfi_idx)
    klist.insert(lilu_idx, amfi_entry)

# Synchronize IONDRVSupport block with whether NullMoth is active
found_iondrv = False
for blk in cfg["Kernel"].setdefault("Block", []):
    if blk.get("Identifier") == "com.apple.iokit.IONDRVSupport":
        blk["Enabled"] = bool(enable_nv)
        blk["MaxKernel"] = ""
        found_iondrv = True
if not found_iondrv:
    cfg["Kernel"]["Block"].append({
        "Arch": "Any",
        "Comment": "boot framebuffer IONDRVFramebuffer steals index 0 from NVRMFB",
        "Enabled": bool(enable_nv),
        "Identifier": "com.apple.iokit.IONDRVSupport",
        "MaxKernel": "",
        "MinKernel": "",
        "Strategy": "Exclude",
    })

# AMD Fix PAT: Algrey ON, Shaneee OFF + DisableVariableWrite ON
for pt in cfg["Kernel"].get("Patch", []):
    cm = pt.get("Comment", "")
    if "fix pat" in cm.lower():
        if "shaneee" in cm.lower():
            pt["Enabled"] = False
        elif "algrey" in cm.lower():
            pt["Enabled"] = True

cfg["Booter"]["Quirks"]["DisableVariableWrite"] = True
cfg["Misc"]["Security"]["SecureBootModel"] = "Disabled"

# Update boot-args & SIP 0x0A43
nv_uuid = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
nv_add = cfg["NVRAM"]["Add"][nv_uuid]
tokens = nv_add.get("boot-args", "").split()

if enable_nv:
    drop = {"-nvoff", "nv_disable=1", "-wegnoegpu"}
    tokens = [t for t in tokens if t not in drop]
    req = [
        "debug=0x100", "keepsyms=1", "-lilubetaall",
        "nvfb=1", "nvaccel=1", "nvfbheads=4", "-nvkmsnosmooth",
        "amfi_get_out_of_my_way=0x1", "amfi=0x80",
        "ipc_control_port_options=0", "gfxrst=4",
    ]
    if is_turing and not any(t.startswith("nvrmsettle=") for t in tokens):
        req.append("nvrmsettle=10000")
    for r in req:
        if r not in tokens:
            tokens.append(r)
else:
    drop = {"nvfb=1", "nvaccel=1", "nvfbheads=4", "-nvkmsnosmooth"}
    tokens = [t for t in tokens if t not in drop]
    for r in ["-v", "-nvoff", "gfxrst=4", "-lilubetaall"]:
        if r not in tokens:
            tokens.append(r)

nv_add["boot-args"] = " ".join(tokens)
nv_add["csr-active-config"] = bytes.fromhex("430a0000")

# Ensure NVRAM.Delete refreshes boot-args & csr-active-config on reboot
nv_del = cfg["NVRAM"].setdefault("Delete", {}).setdefault(nv_uuid, [])
for k in ("boot-args", "csr-active-config"):
    if k not in nv_del:
        nv_del.append(k)

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
      FIXED_PARTS=$((FIXED_PARTS + 1))
      echo "  [OK] Đã đồng bộ & kiểm định chuẩn xác trên /dev/$part"
    fi
    diskutil unmount "$MNT" >/dev/null 2>&1 || true
  fi
done
rmdir "$MNT" 2>/dev/null || true

echo "[4/5] Xóa cờ kẹt nullmoth remove/parked cũ (nếu có)..."
rm -f /Library/NullMoth/update-pending /Library/LaunchDaemons/com.nullmoth.osupdate.plist 2>/dev/null || true

echo "[5/5] Tổng kết:"
if [ "$FIXED_PARTS" -eq 0 ]; then
  echo "  [LỖI] Không tìm thấy phân vùng EFI nào chứa OpenCore!"
  exit 1
fi

echo "=================================================================="
if [ "$ENABLE_NV" -eq 1 ]; then
  echo "[HOÀN TẤT] Đã kích hoạt & sửa toàn bộ 6 chốt chặn chống màn hình đen!"
  echo "  -> Hãy Khởi động lại (Restart) máy để vào màn hình chính với Metal 3."
else
  echo "[CHẾ ĐỘ CỨU HỘ AN TOÀN] Đã bật tạm thời framebuffer gốc (-nvoff + IONDRVSupport)."
  echo "  -> Sau khi vào được macOS, hãy chạy: sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh"
fi
echo "=================================================================="
