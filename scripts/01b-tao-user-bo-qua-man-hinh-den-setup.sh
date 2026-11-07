#!/bin/bash
# ==============================================================================
# BƯỚC 01B: TẠO TÀI KHOẢN ADMIN & BỎ QUA MÀN HÌNH ĐEN SETUP ASSISTANT (TAHOE 26)
# - Trên macOS Tahoe 26, khi cài mới từ đầu trên PC dùng card rời NVIDIA (lúc chưa
#   cài driver NullMoth nên đang chạy VESA Stage 1), màn hình chào mừng lần đầu
#   (Liquid Glass Setup Assistant) sẽ bị ĐEN MÀN HÌNH CHỈ HIỆN CON TRỎ CHUỘT do
#   Setup Assistant đòi shader Metal trước khi cho tạo tài khoản!
# - Chạy script này ngay trong Recovery Terminal (Utilities -> Terminal) sau khi
#   quá trình cài macOS Tahoe hoàn tất để:
#     1) Tự động tìm và mount phân vùng "<Tên Ổ> - Data" (VD: "Macintosh HD - Data")
#     2) Tạo tài khoản Admin (Username + Password tự chọn) bằng công cụ chuẩn dscl
#     3) Đặt cờ .AppleSetupDone để khởi động lại là VÀO THẲNG MÀN HÌNH ĐĂNG NHẬP
#        & DESKTOP (nơi VESA hiển thị bình thường 100%) để cài tiếp Driver RTX 3060!
#
# Cách chạy trong Recovery -> Utilities -> Terminal:
#   bash /Volumes/*/HACKINTOSH-TOOLS/scripts/01b-tao-user-bo-qua-man-hinh-den-setup.sh
# ==============================================================================

set -u

if [ "$(id -u)" -ne 0 ]; then
  echo "Vui long chay voi quyen root / sudo:"
  echo "  sudo bash \"$0\""
  exit 1
fi

echo "=================================================================="
echo " TAO USER ADMIN & BO QUA MAN HINH DEN SETUP ASSISTANT (TAHOE 26)"
echo "=================================================================="

for part in $(diskutil list internal 2>/dev/null | awk '/APFS Volume/{print $NF}'); do
  diskutil mount "/dev/$part" >/dev/null 2>&1 || true
done

DATA_VOL=""
for cand in "/Volumes/Macintosh HD - Data" "/Volumes/macOS Tahoe - Data" /Volumes/*\ -\ Data; do
  if [ -d "$cand/private/var/db/dslocal/nodes/Default" ]; then
    DATA_VOL="$cand"
    break
  fi
done

if [ -z "$DATA_VOL" ]; then
  echo "[LOI] Khong tim thay phan vung '<Ten O> - Data' chua macOS da cai dat!"
  echo "      Hay chay lenh nay SAU KHI qua trinh cai dat macOS Tahoe da hoan tat."
  ls -la /Volumes
  exit 1
fi

NODE_DIR="$DATA_VOL/private/var/db/dslocal/nodes/Default"
echo "  -> Da tim thay o du lieu macOS: $DATA_VOL"
echo ""

USERNAME="${1:-}"
REALNAME="${2:-}"

while [ -z "$USERNAME" ]; do
  printf "Nhap ten tai khoan (viet thuong lien khong dau, vi du: macpro): "
  read -r USERNAME
  USERNAME=$(printf '%s' "$USERNAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g')
  if [ -z "$USERNAME" ]; then
    echo "  [!] Ten tai khoan khong hop le, vui long nhap lai!"
  fi
done

if [ -z "$REALNAME" ]; then
  printf "Nhap ten hien thi day du (nhan Enter de dung '%s'): " "$USERNAME"
  read -r REALNAME
  [ -z "$REALNAME" ] && REALNAME="$USERNAME"
fi

while true; do
  printf "Nhap mat khau cho tai khoan '%s': " "$USERNAME"
  read -r -s PASS1; echo ""
  printf "Nhap lai mat khau de xac nhan : "
  read -r -s PASS2; echo ""
  if [ -z "$PASS1" ]; then
    echo "  [!] Mat khau khong duoc de trong!"
  elif [ "$PASS1" != "$PASS2" ]; then
    echo "  [!] Hai lan nhap mat khau khong khop, vui long nhap lai!"
  else
    break
  fi
done

UID_NUM=501
GID_NUM=20
USER_RECORD="/Local/Default/Users/$USERNAME"

echo ""
if dscl -f "$NODE_DIR" localhost -read "$USER_RECORD" >/dev/null 2>&1; then
  echo "[1/3] Tai khoan '$USERNAME' da ton tai -> Dang cap nhat lai mat khau..."
  dscl -f "$NODE_DIR" localhost -passwd "$USER_RECORD" "$PASS1"
else
  GUID=$(uuidgen)
  echo "[1/3] Dang khoi tao tai khoan Admin '$USERNAME' ($REALNAME)..."
  dscl -f "$NODE_DIR" localhost -create "$USER_RECORD"
  dscl -f "$NODE_DIR" localhost -create "$USER_RECORD" UserShell /bin/zsh
  dscl -f "$NODE_DIR" localhost -create "$USER_RECORD" RealName "$REALNAME"
  dscl -f "$NODE_DIR" localhost -create "$USER_RECORD" UniqueID "$UID_NUM"
  dscl -f "$NODE_DIR" localhost -create "$USER_RECORD" PrimaryGroupID "$GID_NUM"
  dscl -f "$NODE_DIR" localhost -create "$USER_RECORD" GeneratedUID "$GUID"
  dscl -f "$NODE_DIR" localhost -create "$USER_RECORD" NFSHomeDirectory "/Users/$USERNAME"
  dscl -f "$NODE_DIR" localhost -passwd "$USER_RECORD" "$PASS1"

  dscl -f "$NODE_DIR" localhost -append /Local/Default/Groups/admin GroupMembership "$USERNAME"
  dscl -f "$NODE_DIR" localhost -append /Local/Default/Groups/admin GroupMembers "$GUID"
fi

echo "[2/3] Dang tao thu muc Home '/Users/$USERNAME' & kich hoat .AppleSetupDone..."
mkdir -p "$DATA_VOL/Users/$USERNAME"
chown -R "$UID_NUM:$GID_NUM" "$DATA_VOL/Users/$USERNAME"
chmod 755 "$DATA_VOL/Users/$USERNAME"
touch "$DATA_VOL/private/var/db/.AppleSetupDone"
chown 0:0 "$DATA_VOL/private/var/db/.AppleSetupDone" 2>/dev/null || true

echo "[3/3] Kiem tra xac nhan tai khoan Admin..."
dscl -f "$NODE_DIR" localhost -read "$USER_RECORD" UniqueID NFSHomeDirectory UserShell
sync

echo "=================================================================="
echo "[HOAN TAT 100%] Da tao xong User '$USERNAME' va bo qua Setup Assistant!"
echo "BUOC TIEP THEO:"
echo "  1. Go lenh:  reboot"
echo "  2. May se nhay qua man hinh den va VAO THANG MAN HINH DANG NHAP macOS!"
echo "  3. Dang nhap vao Desktop -> Chay tiep scripts/02-cai-driver-rtx3060-sau-tahoe.sh!"
echo "=================================================================="
