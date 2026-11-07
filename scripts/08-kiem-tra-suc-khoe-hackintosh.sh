#!/bin/bash
# ==============================================================================
# BƯỚC 08: KIỂM TRA SỨC KHỎE & BẢO MẬT TOÀN DIỆN HACKINTOSH TAHOE 26
# Chạy không cần sudo để kiểm tra trạng thái hệ thống đang chạy:
#   bash scripts/08-kiem-tra-suc-khoe-hackintosh.sh
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
WARN=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN+1)); }

echo "=================================================================="
echo "KIỂM TRA SỨC KHỎE HỆ THỐNG HACKINTOSH MACOS TAHOE 26"
echo "=================================================================="

echo "1. Hệ điều hành & Phân vùng gốc APFS:"
OS_VER="$(sw_vers -productVersion) (Build $(sw_vers -buildVersion), Kernel $(uname -r))"
echo "   Phiên bản: $OS_VER"
if diskutil info / | grep "Sealed: *Yes" >/dev/null; then
  ok "Ổ hệ thống Macintosh HD giữ nguyên niêm phong Apple (Sealed: Yes — không bị phá bởi Root Patch)"
else
  warn "Ổ hệ thống không ở trạng thái Sealed: Yes"
fi

echo "2. Card đồ họa rời NVIDIA RTX 3060 (Project 1401 / NullMoth):"
SP_DISP=$(system_profiler SPDisplaysDataType 2>/dev/null || true)
if printf '%s\n' "$SP_DISP" | grep "Metal Support: Metal 3" >/dev/null; then
  GPU_NAME=$(printf '%s\n' "$SP_DISP" | awk -F': ' '/Chipset Model/{print $2; exit}')
  VRAM_STR=$(printf '%s\n' "$SP_DISP" | awk -F': ' '/VRAM/{print $2; exit}')
  ok "Đã nhận tăng tốc phần cứng Metal 3 đầy đủ trên $GPU_NAME ($VRAM_STR)"
else
  warn "Chưa kích hoạt được Metal 3 trên card đồ họa rời"
fi

BAR_INFO=$(ioreg -r -n NVRM -d 1 -l 2>/dev/null | grep '"nvrm-bars"' || true)
if [ -n "$BAR_INFO" ]; then
  if printf '%s\n' "$BAR_INFO" | grep "bar1@[^ ]*+0x10000000 " >/dev/null; then
    warn "BAR1 đang bị giới hạn ở 256 MB (hãy bật Above 4G Decoding + Resizable BAR trong BIOS để tránh màn hình đen trỏ chuột)"
  else
    ok "Cửa sổ PCIe BAR1 đã mở rộng (Resizable BAR bật chuẩn — chống tràn bộ nhớ gây màn hình đen trỏ chuột)"
  fi
fi

echo "3. Wi-Fi Native Apple & Bluetooth (Intel Wi-Fi 6E AX210):"
KEXT_LIST=$(kmutil showloaded --list-only 2>/dev/null || kextstat 2>/dev/null || true)
if printf '%s\n' "$KEXT_LIST" | grep "com.zxystd.AirportItlwm" >/dev/null; then
  ok "Kext com.zxystd.AirportItlwm đang hoạt động (Menu Wi-Fi gốc Apple, không cần HeliPort)"
else
  warn "com.zxystd.AirportItlwm chưa được nạp trong nhân"
fi

if printf '%s\n' "$KEXT_LIST" | grep "IntelBluetoothFirmware" >/dev/null || printf '%s\n' "$KEXT_LIST" | grep "BlueToolFixup" >/dev/null; then
  ok "Kext Intel Bluetooth (BlueToolFixup / IntelBluetoothFirmware) đang hoạt động"
else
  warn "Chưa thấy kext Intel Bluetooth nạp trong nhân"
fi

echo "4. OpenCore NVRAM, Chế độ Silent Boot & Hệ điều hành mặc định:"
OC_VER=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:opencore-version 2>/dev/null | awk '{print $2}' || echo "unknown")
ok "Phiên bản OpenCore đang chạy: $OC_VER"

BOOT_ARGS=$(sysctl -n kern.bootargs 2>/dev/null || true)
NVRAM_ARGS=$(nvram boot-args 2>/dev/null | cut -f2- || true)
if ! printf '%s\n' "$BOOT_ARGS" | grep -E '(^| )-v( |$)' >/dev/null; then
  ok "Đã tắt cờ verbose (-v) — Khởi động êm với Logo Táo"
elif [ -n "$NVRAM_ARGS" ] && ! printf '%s\n' "$NVRAM_ARGS" | grep -E '(^| )-v( |$)' >/dev/null; then
  ok "Đã gỡ cờ verbose (-v) trong NVRAM/EFI (hãy Restart máy 1 lần để áp dụng Silent Boot)"
else
  warn "Cờ verbose (-v) vẫn đang bật trong boot-args (màn hình boot còn chạy chữ)"
fi

VOL_GRP=$(diskutil info / | awk -F': *' '/APFS Volume Group/{print $2}' | tr -d ' ')
OCBT_DECODED=$(nvram 4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:OCBt0080 2>/dev/null | sed 's/%00//g' || true)
if [ -n "$VOL_GRP" ] && printf '%s\n' "$OCBT_DECODED" | grep -i "$VOL_GRP" >/dev/null; then
  ok "Hệ điều hành mặc định trong NVRAM đã khóa vào macOS hiện tại ($VOL_GRP)"
else
  warn "Chưa khóa NVRAM OCBt0080 vào ổ macOS hiện tại"
fi

echo "5. Kiểm định cấu hình chuẩn của Repo bằng ocvalidate 1.0.9:"
if [ -x "$REPO_DIR/tools/ocvalidate/ocvalidate" ]; then
  for cname in config.plist config-stage1-cai-moi.plist config-stage2-full-rtx3060.plist; do
    if [ -f "$REPO_DIR/EFI/OC/$cname" ]; then
      OCV=$("$REPO_DIR/tools/ocvalidate/ocvalidate" "$REPO_DIR/EFI/OC/$cname" 2>&1 || true)
      if printf '%s\n' "$OCV" | grep "No issues found." >/dev/null; then
        ok "EFI/OC/$cname đạt chuẩn 100% (ocvalidate: No issues found)"
      else
        warn "ocvalidate báo lưu ý trên EFI/OC/$cname"
      fi
    fi
  done
fi

echo "=================================================================="
echo "TỔNG KẾT: $PASS hạng mục ĐẠT CHUẨN | $WARN lưu ý"
echo "=================================================================="
