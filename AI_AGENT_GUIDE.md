# AI Agent Autonomous Execution Guide (`AI_AGENT_GUIDE.md`)

Tài liệu này được thiết kế chuyên biệt cho các **AI Coding / System Agents** (**Google Antigravity, Claude Code, Cursor, OpenAI Codex, Windsurf**) khi người dùng mở repository này trên **Windows 10/11** hoặc **macOS** và yêu cầu AI hỗ trợ tạo USB cài đặt mới từ con số 0, nâng cấp lên macOS Tahoe 26, cài đặt driver NVIDIA RTX 3060 (`NullMoth`), xử lý lỗi màn hình đen cùng con trỏ chuột, vá Wi-Fi Dual-Boot Intel AX210, hoặc bật giao diện OpenCanopy 4K.

---

## 1. Bất biến An toàn Tuyệt đối (CRITICAL SAFETY INVARIANTS)

Trước khi thực hiện bất kỳ thao tác ghi nào lên hệ thống, USB hoặc phân vùng EFI của người dùng, AI Agent **BẮT BUỘC** tuân thủ 9 quy tắc bất biến sau:

1. **PHÂN BIỆT NGHIÊM NGẶT CONFIG STAGE 1 (CÀI MỚI TỪ USB) VÀ STAGE 2 (SAU KHI CÀI NULLMOTH)**:
   - **Stage 1 (`EFI/OC/config-stage1-cai-moi.plist`) — BẮT BUỘC dùng khi tạo USB cài mới macOS trên Windows/macOS trước khi cài driver NullMoth**:
     - `Kernel -> Block -> com.apple.iokit.IONDRVSupport -> Enabled = False` (Bộ cài USB và macOS mới cài lần đầu cần UEFI GOP framebuffer `IONDRVSupport` để xuất hình; nếu chặn `Enabled = True` trước khi cài `NVRMFB.kext` vào `/Library/Extensions`, máy sẽ mất hình hoàn toàn!).
     - `boot-args` có `-v` và `-nvoff`.
   - **Stage 2 (`EFI/OC/config-stage2-full-rtx3060.plist` / `EFI/OC/config.plist`) — CHỈ bật sau khi đã cài gói driver Project 1401 (`NullMoth`) vào `/Library/KernelCollections/AuxiliaryKernelExtensions.kc`**:
     - `Kernel -> Block -> com.apple.iokit.IONDRVSupport -> Enabled = True` (`MaxKernel = ""`) để ngăn `IONDRVFramebuffer` cướp Display Index 0 của `NVRMFB`.
     - `boot-args` gỡ `-nvoff` và giữ đầy đủ bộ cờ chống màn hình đen.
2. **KHÔNG BAO GIỜ dùng nguyên Serial/MLB/UUID mẫu (`W00000000001`) cho máy người dùng**:
   - Trên Windows: Chạy `scripts\windows\02-chuan-bi-efi-cai-moi-windows.cmd` (`prepare-efi-stage1.ps1`).
   - Trên macOS/Linux: Chạy `bash scripts/00-tao-smbios-rieng.sh` (thêm `--stage1` nếu chuẩn bị USB cài mới, hoặc `--apply-efi` nếu ghi lên ổ cứng đang chạy).
   - Khi đẩy code lên Git công khai (`git push`), bắt buộc kiểm tra cả 3 tệp `config.plist`, `config-stage1-cai-moi.plist`, `config-stage2-full-rtx3060.plist` đều giữ nguyên placeholder `W00000000001` — **tuyệt đối không làm lộ Serial/UUID/MAC thật của người dùng**.
3. **BIOS CHO NVIDIA NULLMOTH BẮT BUỘC BẬT `Above 4G Decoding = Enabled` VÀ `Resizable BAR = Enabled`**:
   - Khác với GPU AMD Radeon truyền thống, driver NVIDIA NullMoth cần cửa sổ PCIe `BAR1 >= 4GB / 8GB`. Nếu `Resizable BAR` bị tắt trong BIOS làm `BAR1 = 256 MB` (`0x10000000`), cửa sổ 256 MB sẽ tràn ngay ở màn hình đăng nhập gây **lỗi màn hình đen chỉ hiện con trỏ chuột**!
   - Trong OpenCore `config.plist`, giữ `UEFI.Quirks.ResizeGpuBars = -1` và `Booter.Quirks.ResizeAppleGpuBars = 0` để bảo toàn BAR 8 GB từ BIOS mà không làm treo UEFI firmware.
4. **KHÔNG BAO GIỜ chạy OCLP Root Patch trên macOS Tahoe 26 khi dùng Project 1401 / NullMoth**:
   - Ổ hệ thống `Macintosh HD` phải luôn giữ **`Sealed: Yes`** (`diskutil info / | grep Sealed`).
   - Wi-Fi Native Apple cho Intel AX210 trên Tahoe 26 hoạt động trực tiếp từ `EFI/OC/Kexts/AirportItlwm_Tahoe.kext` (`MinKernel = 25.0.0`, `MaxKernel = 25.99.99`).
5. **KHÔNG BAO GIỜ nạp đồng thời `itlwm.kext` và `AirportItlwm_Tahoe.kext`**:
   - Khi `AirportItlwm_Tahoe.kext` có `Enabled = True`, `itlwm.kext` phải có `Enabled = False` (và bộ kext Sequoia cũ `IOSkywalkFamily`, `IO80211FamilyLegacy`, `AirportItlwm` phải khóa cứng ở `MaxKernel = 24.99.99`).
6. **KHÔNG BAO GIỜ trộn lẫn các file `.efi` của OpenCore khác phiên bản build**:
   - Mọi file `.efi` (`BOOTx64.efi`, `OpenCore.efi`, `OpenRuntime.efi`, `ResetNvramEntry.efi`, `OpenCanopy.efi`) phải đồng bộ cùng bản build `OpenCore 1.0.9 (f4a7e45)`.
7. **BẢO TOÀN 100% 6 CHỐT CHẶN CHỐNG "MÀN HÌNH ĐEN CÙNG CON TRỎ CHUỘT" (Stage 2)**:
   - `Lilu.kext` (`Enabled = True`) phải đứng **trước** `AMFIPass.kext` (`Enabled = True`) trong `Kernel -> Add` (nếu thiếu `AMFIPass` hoặc thiếu `-lilubetaall` trên Tahoe 26, `WindowServer` từ chối map bundle Metal làm màn hình tối đen chỉ còn trỏ chuột!).
   - `boot-args` Stage 2 bắt buộc giữ: `debug=0x100 keepsyms=1 -lilubetaall nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 gfxrst=4` (thêm `nvrmsettle=10000` nếu phát hiện GPU kiến trúc Turing `0x1E00–0x1FFF` hoặc `0x2180–0x21FF`).
   - `csr-active-config = 430A0000` (`0x0A43`) và `Misc.Security.SecureBootModel = Disabled`.
   - Trên CPU AMD: bản vá nhân `Algrey / Zormeister - Fix PAT` phải `Enabled = True`, còn `Shaneee - Fix PAT` phải `Enabled = False` (bật Shaneee gây lỗi `RmInitAdapter failed!`), và `Booter.Quirks.DisableVariableWrite = True` (chống treo NVRAM trên bo mạch chủ AM5).
   - `Misc.Security.ExposeSensitiveData = 7` và `Misc.Debug.Target = 66` (khi tắt chữ `[OC]`).
8. **LUÔN kiểm tra Kernel ABI trước khi cài `AirportItlwm_Tahoe.kext` & bảo vệ `EFI/Microsoft`**:
   - Chạy `kmutil libraries --bundle-path EFI/OC/Kexts/AirportItlwm_Tahoe.kext` trước khi ghi lên máy đang chạy Tahoe mới hơn `26.7.2`. Nếu khác `0`, chạy `bash patches/build-airportitlwm-tahoe.sh` biên dịch lại trước.
   - **Tuyệt đối không bao giờ xóa hoặc ghi đè `EFI/Microsoft`** khi thao tác trên phân vùng ESP Dual-Boot! Luôn chạy `plutil -lint`, `ocvalidate`, và `dot_clean -m` trước khi unmount.
9. **Quy tắc viết Shell Script dưới `set -euo pipefail`**:
   - Không bao giờ dùng `grep -q` sau đường ống pipe lớn (như `nm ... | grep -q`), vì đóng pipe sớm gây `SIGPIPE (141)` làm vỡ script. Luôn dùng `grep "..." >/dev/null`.

---

## 2. Quy trình Tự động Điều chỉnh Số Nhân CPU AMD Ryzen (Cả 4 Bản Vá!)

Nếu CPU AMD Ryzen của người dùng có số nhân vật lý khác `6` (ví dụ `8` nhân trên Ryzen 7 7700X/7800X3D/9700X, `12` nhân trên Ryzen 9 7900X, `16` nhân trên Ryzen 9 7950X):
- Trên Windows: `scripts\windows\prepare-efi-stage1.ps1` đã **tự động phát hiện `Win32_Processor.NumberOfCores` và sửa cả 4 bản vá**!
- Trên macOS/Linux: Chạy `bash scripts/00-tao-smbios-rieng.sh --cores <SO_NHAN>` để cập nhật đầy đủ **cả 4 bản vá** `algrey | Force cpuid_cores_per_package`:
  1. `10.13-10.14`: `B8 <HEX_CORES> 00 00 00 00`
  2. `10.15-11.0`: `BA <HEX_CORES> 00 00 00 00`
  3. `12.0-13.2`: `BA <HEX_CORES> 00 00 00 90`
  4. **`13.3+` (Áp dụng cho Sonoma 14, Sequoia 15 & Tahoe 26!)**: `BA <HEX_CORES> 00 00 00` *(5 bytes — tuyệt đối không bỏ sót dòng thứ 4 này!)*.

---

## 3. Cây Quyết định Thực thi Tự động theo Môi trường

### Kịch bản A: Người dùng đang ở trên WINDOWS 10/11 và muốn cài mới từ đầu
1. Hướng dẫn người dùng chia phân vùng `ExFAT` tên `MACOS_INSTALL` trong Disk Management và format USB `16GB–32GB` chuẩn **FAT32 + GPT** bằng Rufus (*Non bootable*).
2. Chạy `scripts\windows\fix-wifi-dualboot-windows11.cmd` (Run as Administrator).
3. Chạy `scripts\windows\01-tai-macos-tahoe-recovery.cmd` để tải `com.apple.recovery.boot` vào USB (hoặc tải `1401-Windows-2.7.2.zip` từ `https://github.com/nullmoth/1401/releases/latest`).
4. Chạy `scripts\windows\02-chuan-bi-efi-cai-moi-windows.cmd` để tự sinh SMBIOS, tự chỉnh số nhân Ryzen, nạp **Stage 1** (`IONDRVSupport = False`, `-nvoff -v`), kiểm định `ocvalidate.exe`, và chép `EFI\` + `HACKINTOSH-TOOLS\` sang USB.
5. Nhắc người dùng kiểm tra BIOS (`Above 4G Decoding = Enabled`, **`Resizable BAR = Enabled`**, `CSM = Disabled`, `Secure Boot = Disabled`) trước khi boot USB.

### Kịch bản B: Vừa cài mới xong macOS Tahoe 26 từ USB (Đang ở Stage 1) -> Lên Full Hoàn Thiện (Stage 2)
Thực thi tuần tự 4 script:
```bash
# 1. Tự tải (kèm check SHA-256 từ GitHub NullMoth) hoặc cài Offline driver RTX 3060 & nâng EFI lên Stage 2
sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh

# 2. Kích hoạt Wi-Fi Native AX210 + bản vá C++ Dual-Boot FLR
sudo bash scripts/03-kich-hoat-wifi-native-ax210.sh

# 3. Bật giao diện OpenCanopy 4K dùng chuột + Silent Boot + Khóa mặc định mở macOS
sudo bash scripts/05-bat-giao-dien-opencanopy-ui.sh

# 4. Chép bộ OpenCore hoàn chỉnh vào ổ NVMe cạnh EFI/Microsoft của Windows 11
sudo bash scripts/10-chep-efi-usb-vao-nvme-dualboot.sh
```

### Kịch bản C: Người dùng báo lỗi "Màn hình đen chỉ hiện con trỏ chuột" (Black Screen + Cursor Only)
1. Nếu đang không thấy màn hình: hướng dẫn tại OpenCanopy nhấn **`Space`** → chọn **`1401: Start once without NVIDIA driver`** → chọn **`Macintosh HD`**.
2. Khi vào được Terminal (hoặc SSH / Recovery), chạy ngay:
   ```bash
   sudo bash scripts/09-sua-loi-man-hinh-den-con-tro-chuot.sh
   ```
3. Đọc kết quả bước `[1/5]` của script: nếu báo `BAR1` chỉ có `256 MB (0x10000000)`, nhắc người dùng vào BIOS bật **`Above 4G Decoding = Enabled`** và **`Resizable BAR = Enabled`**.

### Kịch bản D: Sửa lỗi mất Wi-Fi khi Restart từ Windows 11 sang macOS Tahoe (Intel AX210)
1. Kiểm tra ABI bằng `kmutil libraries --bundle-path EFI/OC/Kexts/AirportItlwm_Tahoe.kext` (nếu lệch ABI thì chạy `bash patches/build-airportitlwm-tahoe.sh`).
2. Chạy `sudo bash scripts/04-cap-nhat-wifi-dualboot-ax210.sh` trên macOS và `scripts\windows\fix-wifi-dualboot-windows11.cmd` (Admin) bên Windows 11.

---

## 4. Kiểm tra Nghiệm thu Sau Cùng (Post-Execution Verification)

Sau mọi thay đổi, AI Agent luôn chạy script kiểm tra sức khỏe (không cần `sudo`):

```bash
bash scripts/08-kiem-tra-suc-khoe-hackintosh.sh
```
