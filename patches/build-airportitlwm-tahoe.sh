#!/bin/bash
# ==============================================================================
# BUILD TU NGUON C++: AirportItlwm_Tahoe.kext (Kèm bản vá Dual-Boot Warm-Reboot)
# Tự động clone laobamac/itlwm (tag v2.4.0-alpha / 7204c69), áp dụng bản vá
# PCIe D0A / MSI-X / DMA Quiesce + PCIe FLR cho Intel AX210, và biên dịch bằng Xcode.
#
# Yêu cầu: Xcode.app đầy đủ trên macOS
# Cách chạy:
#   bash patches/build-airportitlwm-tahoe.sh
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$REPO_DIR/patches/itlwm-tahoe-ax210-warm-reboot.patch"
WORK_DIR="${WORK_DIR:-/tmp/itlwm-tahoe-build}"
UPSTREAM_URL="https://github.com/laobamac/itlwm.git"
UPSTREAM_COMMIT="7204c69"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[LỖI] Không tìm thấy xcodebuild. Vui lòng cài đặt Xcode.app đầy đủ!"
  exit 1
fi

if [ ! -f "$PATCH_FILE" ]; then
  echo "[LỖI] Không tìm thấy file patch: $PATCH_FILE"
  exit 1
fi

echo "[1/4] Tải mã nguồn gốc laobamac/itlwm ($UPSTREAM_COMMIT)..."
rm -rf "$WORK_DIR"
git clone "$UPSTREAM_URL" "$WORK_DIR"
git -C "$WORK_DIR" checkout "$UPSTREAM_COMMIT"

echo "[2/4] Áp dụng bản vá Dual-Boot Warm-Reboot AX210..."
git -C "$WORK_DIR" apply "$PATCH_FILE"

echo "[3/4] Biên dịch AirportItlwm-Tahoe (Release x86_64)..."
xcodebuild \
  -project "$WORK_DIR/itlwm.xcodeproj" \
  -scheme "AirportItlwm-Tahoe" \
  -configuration Release \
  -jobs "$(sysctl -n hw.ncpu)" \
  ARCHS=x86_64 \
  SYMROOT="$WORK_DIR/build/products" \
  OBJROOT="$WORK_DIR/build/obj" \
  CODE_SIGNING_ALLOWED=NO \
  GIT_COMMIT="_${UPSTREAM_COMMIT}_ax210fix" \
  build

BUILT_KEXT=$(find "$WORK_DIR/build/products/Release" -maxdepth 2 -name "AirportItlwm*.kext" -print -quit)
if [ -z "$BUILT_KEXT" ] || [ ! -f "$BUILT_KEXT/Contents/MacOS/AirportItlwm" ]; then
  echo "[LỖI] Không tìm thấy kext sau khi biên dịch!"
  exit 1
fi

echo "[4/4] Kiểm tra ký hiệu bản vá & cập nhật vào EFI/OC/Kexts/AirportItlwm_Tahoe.kext..."
if ! nm "$BUILT_KEXT/Contents/MacOS/AirportItlwm" | grep "iwx_quiesce_warm_boot_hw" >/dev/null; then
  echo "[LỖI] Binary vừa build thiếu ký hiệu iwx_quiesce_warm_boot_hw!"
  exit 1
fi

rm -rf "$REPO_DIR/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"
cp -R "$BUILT_KEXT" "$REPO_DIR/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"
strip -S "$REPO_DIR/EFI/OC/Kexts/AirportItlwm_Tahoe.kext/Contents/MacOS/AirportItlwm"
xattr -cr "$REPO_DIR/EFI/OC/Kexts/AirportItlwm_Tahoe.kext" 2>/dev/null || true

NEW_SHA=$(shasum -a 256 "$REPO_DIR/EFI/OC/Kexts/AirportItlwm_Tahoe.kext/Contents/MacOS/AirportItlwm" | awk '{print $1}')
echo "=================================================================="
echo "[HOÀN TẤT] Đã build thành công AirportItlwm_Tahoe.kext!"
echo "  Đường dẫn : $REPO_DIR/EFI/OC/Kexts/AirportItlwm_Tahoe.kext"
echo "  SHA-256   : $NEW_SHA"
echo "=================================================================="
