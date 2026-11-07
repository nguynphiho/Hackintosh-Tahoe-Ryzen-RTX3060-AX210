# Hackintosh macOS Tahoe 26 — AMD Ryzen (AM5) + NVIDIA RTX 3060 + Intel Wi-Fi 6E AX210 (Dual-Boot Windows 11)

Bộ cài đặt, cấu hình **OpenCore `1.0.9`** hoàn chỉnh và hệ thống **Scripts tự động hóa từ A–Z** để chạy **macOS Tahoe `26.x` (Darwin `25.x`)** ổn định như Mac thật trên cấu hình PC **AMD Ryzen Zen 4 + Card rời NVIDIA RTX 3060 + Wi-Fi/Bluetooth Intel AX210** song song **Windows 11** trên cùng 1 ổ NVMe.

> **Dành cho AI Coding Agent (Antigravity / Claude Code / Cursor / Codex):** Nếu bạn đang nhờ AI đọc repo này để tự động cài đặt hoặc tối ưu máy cho bạn, hãy bảo AI đọc tệp **[`AI_AGENT_GUIDE.md`](./AI_AGENT_GUIDE.md)** — trong đó đã có sẵn toàn bộ quy trình kiểm tra phần cứng, quy tắc an toàn tuyệt đối và lệnh thực thi chuẩn từng bước.

---

## Điểm nổi bật của bản dựng này

1. **Giữ nguyên niêm phong hệ thống Apple (`Sealed: Yes`)**: Không dùng OCLP Root Patch can thiệp vào phân vùng hệ thống macOS Tahoe — an toàn bảo mật, không vỡ snapshot APFS.
2. **Full tăng tốc đồ họa Metal 3 trên NVIDIA GeForce RTX 3060 (12GB)**: Hỗ trợ màn hình tần số quét cao (`100Hz+` / HiDPI), xuất âm thanh HDMI/DisplayPort 8 kênh và Realtek ALC897 thông qua gói driver **Project 1401 (`NullMoth v2.7.2+`)**, kèm script tự động gom gọn các tác vụ nền dưới `1401.app` (không bị hiện các mục `bash` lạ trong *System Settings → Login Items*).
3. **Wi-Fi Native Apple gốc trên macOS Tahoe 26 cho card Intel AX210 (`AirportItlwm_Tahoe.kext`)**: Dùng trực tiếp biểu tượng Wi-Fi trên thanh Menu Bar và *System Settings → Wi-Fi* của macOS **không cần HeliPort**.
4. **Bản vá độc quyền C++ sửa lỗi mất Wi-Fi khi Restart ấm từ Windows 11 sang macOS**: Khắc phục triệt để bệnh kinh niên của card Intel AX210 trên máy Dual-Boot (driver `Netwtw10.sys` của Windows giữ trạng thái `D0A` / `MSI-X` / `DMA` khiến sang macOS mất Wi-Fi ở lần boot đầu) bằng cơ chế `iwx_quiesce_warm_boot_hw` + **PCIe Function-Level Reset (`FLR`)** ngay trong nhân.
5. **Giao diện chọn Hệ điều hành đồ họa 4K (`OpenCanopy` + `GoldenGate`) & Silent Boot**: Màn hình chọn **macOS / Windows** nền núi 4K sắc nét, điều khiển được bằng cả **Chuột** lẫn bàn phím, tự động vào macOS sau 5 giây và hiện thẳng **Logo Táo + thanh chạy** (tắt sạch dòng chữ log đen trắng `-v`).
6. **Tương thích Dual-Kernel (`macOS Sequoia 15` & `macOS Tahoe 26`)**: Phân tách rõ `MinKernel`/`MaxKernel` cho cả `Darwin 24.x` và `Darwin 25.x` trong cùng 1 bộ `EFI`.

---

## Cấu hình phần cứng chuẩn (Reference Hardware)

| Thành phần | Phần cứng thực tế đã kiểm chứng | Driver / Kext xử lý | Trạng thái trên Tahoe 26 |
| :--- | :--- | :--- | :--- |
| **CPU** | AMD Ryzen 5 7500F (6 nhân / 12 luồng, Zen 4 AM5) | 25 bản vá nhân AMD Vanilla (`algrey` / `Shaneee`) | Hoạt động 100% |
| **RAM** | 32 GB DDR5 | `RestrictEvents.kext` + SMBIOS `MacPro7,1` | Hoạt động 100% |
| **GPU** | NVIDIA GeForce RTX 3060 12GB (`0x10de:0x2504`) | `WhateverGreen` (`gfxrst=4`) + **Project 1401 (`NullMoth v2.7.2+`)** | Full Metal 3, 100Hz+, HDMI/DP Audio |
| **Wi-Fi** | Intel Wi-Fi 6E AX210 (`pci8086,2725`) | `AirportItlwm_Tahoe.kext` (đã vá C++ Dual-Boot FLR) | Menu Wi-Fi gốc Apple (Native) |
| **Bluetooth** | Intel AX210 USB Bluetooth | `IntelBluetoothFirmware` + `IntelBTPatcher` + `BlueToolFixup` | Hoạt động 100% |
| **LAN** | Realtek 2.5GbE Ethernet | `RTL812xLucy.kext` | Hoạt động 100% |
| **Âm thanh** | Realtek ALC897 + NVIDIA HDMI/DP | `AppleALC.kext` / NullMoth Audio | Đầu ra & Micro đầy đủ |
| **Ổ cứng** | 1TB Kingston NV2 PCIe 4.0 NVMe (`SNV2S1000G`) | `NVMeFix.kext` (Chia GPT Dual-Boot Win 11 + macOS) | TRIM + APFS Sealed: Yes |
| **Bootloader** | OpenCore `1.0.9` (`f4a7e45`) + `OpenCanopy.efi` | Theme `Acidanthera\GoldenGate` 4K | Chuột + Phím + Silent Boot |

> **Lưu ý nếu máy bạn khác số nhân CPU hoặc khác Mainboard:**
> - **Khác số nhân CPU AMD Ryzen**: Mở `EFI/OC/config.plist` → mục `Kernel -> Patch`, tìm 3 mục `algrey - Force cpuid_cores_per_package` và đổi byte thứ 2 (`06` tương ứng 6 nhân của Ryzen 5 7500F) thành số nhân vật lý thực của CPU bạn ở hệ thập lục phân (`08` cho 8 nhân, `0C` cho 12 nhân, `10` cho 16 nhân).
> - **Khác Mainboard**: Khuyến nghị tạo lại `UTBMap.kext` riêng bằng công cụ `USBToolBox` trên Windows để ánh xạ đúng 15 cổng USB của bo mạch chủ của bạn.

---

## Cấu trúc thư mục Repository

```text
Hackintosh-Tahoe-Ryzen-RTX3060-AX210/
├── README.md                                 # Tài liệu hướng dẫn toàn diện từng bước (tệp này)
├── AI_AGENT_GUIDE.md                         # Playbook kỹ thuật chi tiết cho AI Agent thực thi tự động
├── AGENTS.md / CLAUDE.md                     # Điểm vào tự động cho Antigravity, Cursor, Codex, Claude Code
├── EFI/                                      # Bộ OpenCore 1.0.9 hoàn chỉnh (đã làm sạch Serial cá nhân)
│   ├── Boot/BOOTx64.efi
│   └── OC/                                   # ACPI, Drivers (kèm OpenCanopy), Kexts, Resources 4K, Tools, config.plist
├── patches/                                  # Mã nguồn C++ vá lỗi mất Wi-Fi Dual-Boot Windows <-> macOS
│   ├── itlwm-tahoe-ax210-warm-reboot.patch   # Git diff chuẩn trên laobamac/itlwm (commit 7204c69)
│   ├── build-airportitlwm-tahoe.sh           # Script tự động tải nguồn + vá + biên dịch lại kext bằng Xcode
│   └── README.md                             # Phân tích nguyên nhân kỹ thuật PCIe D0A / MSI-X / FLR
├── scripts/                                  # Bộ Scripts tự động hóa từng giai đoạn
│   ├── 00-tao-smbios-rieng.sh                # Tạo Serial / MLB / UUID / ROM MacPro7,1 riêng cho từng máy
│   ├── 01-chuan-bi-len-tahoe.sh              # Chuẩn bị EFI khi nâng cấp từ macOS Sequoia 15 lên Tahoe 26
│   ├── 02-cai-driver-rtx3060-sau-tahoe.sh    # Cài driver RTX 3060 (NullMoth) + gom gọn mục nền 1401
│   ├── 03-kich-hoat-wifi-native-ax210.sh     # Bật Wi-Fi Native Apple trên Tahoe 26 (gỡ HeliPort & OCLP cũ)
│   ├── 04-cap-nhat-wifi-dualboot-ax210.sh    # Cập nhật nhanh kext vá lỗi Restart từ Windows sang macOS
│   ├── 05-bat-giao-dien-opencanopy-ui.sh     # Bật UI chọn HĐH 4K dùng chuột + tắt chữ log verbose (-v)
│   ├── 06-khoi-phuc-boot-log-verbose.sh      # Bật lại chữ log (-v) khi cần gỡ lỗi
│   ├── 07-khoi-phuc-wifi-heliport.sh         # Chuyển dự phòng về itlwm + HeliPort chỉ với 1 lệnh
│   ├── 08-kiem-tra-suc-khoe-hackintosh.sh    # Kiểm tra toàn diện hệ thống sau khi hoàn tất
│   └── windows/fix-wifi-dualboot-windows11.cmd # Tắt Fast Startup / Hiberboot & WoWLAN bên Windows 11
└── tools/                                    # Công cụ gốc OpenCore 1.0.9 cho cả macOS, Windows (.exe) & Linux
    ├── macserial/                            # Sinh mã Serial/MLB chuẩn Apple
    ├── ocvalidate/                           # Kiểm định cú pháp & cấu trúc config.plist
    ├── icnspack/                             # Đóng gói hình nền 4K mới thành Background.icns
    └── macrecovery/                          # Tải bộ cài macOS Recovery chính gốc từ máy chủ Apple
```

---

## Hướng dẫn cài đặt chi tiết từng bước (Từ A đến Z)

### Bước 1: Thiết lập BIOS chuẩn cho Hackintosh AMD + RTX 3060
Vào BIOS của bo mạch chủ và thiết lập:
- **Tắt (Disable)**: `Fast Boot`, `Secure Boot`, `CSM (Compatibility Support Module)`, `Serial/COM Port`.
- **Bật (Enable)**: `Above 4G Decoding`, `EHCI/XHCI Hand-off`, `SATA Mode: AHCI`.
- **Resizable BAR / Smart Access Memory**: Để `Disabled` (hoặc cấu hình `ResizeAppleGpuBars = 0` nếu bật).

---

### Bước 2: Tạo mã định danh SMBIOS riêng (BẮT BUỘC để không trùng Apple ID)
Bộ `EFI/OC/config.plist` trong repo đã được xóa sạch mã Serial cá nhân về giá trị mẫu an toàn (`W00000000001`). Trước khi chép EFI vào USB/ổ cứng và đăng nhập iCloud, hãy tạo mã Serial `MacPro7,1` riêng cho máy của bạn:

- **Trên macOS hoặc Linux**:
  ```bash
  bash scripts/00-tao-smbios-rieng.sh
  ```
  *(Hoặc nếu máy đang chạy OpenCore sẵn trên ổ cứng, thêm cờ `--apply-efi`: `sudo bash scripts/00-tao-smbios-rieng.sh --apply-efi`).*
- **Trên Windows (nếu bạn đang tạo USB cài mới từ Windows)**:
  Chạy `tools\macserial\macserial.exe -m MacPro7,1 -n 1` trong Command Prompt, tạo thêm 1 UUID bằng `powershell -Command "[guid]::NewGuid().ToString().ToUpper()"`, rồi điền `SystemSerialNumber`, `MLB`, `SystemUUID` và `ROM` vào `EFI/OC/config.plist` bằng [ProperTree](https://github.com/corpnewt/ProperTree).

---

### Bước 3: Cài mới Dual-Boot HOẶC Nâng cấp từ macOS Sequoia 15 lên Tahoe 26

#### Trường hợp A — Cài mới Dual-Boot cùng Windows 11 trên 1 ổ NVMe
1. Trong **Windows Disk Management**:
   - Đảm bảo phân vùng **EFI System Partition (`ESP`)** có dung lượng tối thiểu **200 MB – 300 MB** (chuẩn `314 MB`).
   - Dùng `Shrink Volume` trên ổ Windows để chừa vùng trống rồi tạo 1 phân vùng tạm (ExFAT/NTFS) đặt tên dễ nhớ (ví dụ `MACOS`) cho macOS.
2. Tạo bộ cài USB OpenCore:
   - Format 1 USB (tối thiểu 16GB–32GB) theo chuẩn **GUID Partition Map (GPT) — FAT32**.
   - Tải bộ cài Recovery bằng `python3 tools/macrecovery/macrecovery.py` (chép thư mục `com.apple.recovery.boot` vào gốc USB) **hoặc** tạo USB bộ cài Offline đầy đủ từ `Install macOS Tahoe.app` bằng `createinstallmedia`.
   - Chép nguyên thư mục **`EFI`** (sau khi đã chạy Bước 2 tạo SMBIOS riêng) vào gốc USB.
   - *(Mẹo khi mới cài lần đầu)*: Nếu muốn theo dõi dòng chữ tiến trình lúc cài đặt, giữ tổ hợp phím **`Win + V`** (hoặc `Cmd + V`) tại màn hình chọn hệ điều hành.
3. Boot vào USB → mở **Disk Utility** → nhấn `View -> Show All Devices` → chọn phân vùng `MACOS` vừa chia (tuyệt đối không xóa nhầm phân vùng `Windows`!) → nhấn **Erase** thành định dạng **APFS** tên `Macintosh HD` → thoát Disk Utility và tiến hành cài đặt macOS Tahoe 26.
4. Sau khi vào được màn hình chính của macOS Tahoe, mount phân vùng EFI của ổ cứng NVMe và chép thư mục `EFI/Boot` + `EFI/OC` vào cạnh thư mục `EFI/Microsoft` (giữ nguyên thư mục `Microsoft` của Windows để OpenCore hiển thị song song cả **Windows** và **Macintosh HD**!).

#### Trường hợp B — Đang chạy macOS Sequoia 15 và muốn nâng cấp lên macOS Tahoe 26
1. Chạy script chuẩn bị EFI Dual-Kernel trước khi bấm cập nhật:
   ```bash
   sudo bash scripts/01-chuan-bi-len-tahoe.sh
   ```
   *(Script tự động sao lưu toàn bộ EFI hiện tại ra Desktop, giới hạn các kext OCLP cũ của Sequoia ở `Darwin 24.x` để không gây Kernel Panic trên Tahoe `25.x`, và nạp sẵn `AirportItlwm_Tahoe.kext`).*
2. Mở bộ cài **`Install macOS Tahoe.app`** (hoặc cập nhật qua *System Settings → Software Update*) và để máy tự khởi động lại hoàn tất nâng cấp.

---

### Bước 4: Cài đặt Driver Card rời NVIDIA RTX 3060 (Full Metal 3 + Audio)
Do bộ cài Project 1401 (`NullMoth`) có dung lượng lớn (`~265 MB`) và phát hành riêng, repo không đính kèm file `.tar.gz` bên trong Git. Bạn đặt `1401-Mac-2.7.2.dmg` và `nullmoth-nvidia-2.7.2.tar.gz` vào `~/Downloads` (hoặc ổ USB), sau đó chạy:

```bash
sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh ~/Downloads
```

- Mở **System Settings → Privacy & Security**, bấm **Allow** nếu macOS hỏi quyền nạp phần mở rộng, sau đó **Restart** máy 1 lần.
- Script đã tự động mở khóa chặn `IONDRVSupport` cho Tahoe 26 và gắn `AssociatedBundleIdentifiers = com.nullmoth.1401` để *System Settings → Login Items* hiển thị gọn gàng dưới tên ứng dụng `1401` thay vì các mục `bash` vô danh.

---

### Bước 5: Kích hoạt Wi-Fi Native Apple & Vá triệt để lỗi Dual-Boot Windows ↔ macOS (Intel AX210)

#### 5.1. Trên macOS Tahoe 26
Chạy lệnh sau để kích hoạt `AirportItlwm_Tahoe.kext` (đã tích hợp sẵn bản vá C++ PCIe FLR Warm-Reboot), gỡ bỏ `HeliPort` và dọn sạch các tiến trình ngầm OCLP cũ (nếu từng nâng cấp từ Sequoia):

```bash
sudo bash scripts/03-kich-hoat-wifi-native-ax210.sh
```
*(Nếu máy bạn đã bật Wi-Fi Native từ trước và chỉ muốn cập nhật riêng bản vá sửa lỗi mất Wi-Fi khi Restart từ Windows sang macOS mà giữ nguyên toàn bộ mật khẩu Wi-Fi đã lưu, chạy `sudo bash scripts/04-cap-nhat-wifi-dualboot-ax210.sh`).*

#### 5.2. Trên Windows 11 (Khuyến nghị chạy thêm 1 lần)
Sang Windows 11, chuột phải vào tệp **`scripts\windows\fix-wifi-dualboot-windows11.cmd`** → chọn **Run as administrator** để tắt *Fast Startup (Hiberboot)* và *WoWLAN D3*, giúp Windows giải phóng bus PCIe sạch sẽ nhất khi tắt máy / khởi động lại.

---

### Bước 6: Bật giao diện chọn Hệ điều hành 4K (`OpenCanopy`) & Tắt chữ Log khởi động
Để bật màn hình chọn **Windows / Macintosh HD** đồ họa 4K dùng được chuột, ẩn các công cụ cứu hộ cho gọn, tắt sạch chữ log đen trắng (`-v`) và khóa **macOS** làm hệ điều hành mặc định sau 5 giây:

```bash
sudo bash scripts/05-bat-giao-dien-opencanopy-ui.sh
```

#### Phím tắt hữu ích tại màn hình chọn Hệ điều hành (OpenCanopy)
- **Click Chuột** hoặc phím **`←` / `→` + `Enter`**: Chọn khởi động vào **Macintosh HD** hoặc **Windows**.
- **`Ctrl + Enter`** (hoặc **`Ctrl + Click chuột`**): Đặt hệ điều hành đang chọn làm mặc định.
- **Phím `Space` (Phím Cách)**: Hiện đầy đủ các mục ẩn gồm `Recovery`, `Reset NVRAM`, và `1401: Start once without NVIDIA driver` / `1401: Remove NVIDIA driver`.
- **Giữ `Win/Cmd + V`** khi bấm chọn macOS: Bật xem dòng chữ log tạm thời trong đúng 1 lần khởi động đó (rất tiện khi muốn kiểm tra lỗi mà không cần sửa `config.plist`).

---

### Bước 7: Kiểm tra sức khỏe toàn diện sau cài đặt
Sau khi khởi động lại, mở Terminal chạy lệnh kiểm tra tổng thể (không cần `sudo`):

```bash
bash scripts/08-kiem-tra-suc-khoe-hackintosh.sh
```

Khi tất cả các hạng mục báo **`[PASS]`** (`Sealed: Yes`, `Metal Support: Metal 3`, `com.zxystd.AirportItlwm`, `IntelBluetoothFirmware`, `Silent Boot`, `OCBt0080 Default OS`, `ocvalidate: No issues found`), cỗ máy Hackintosh Tahoe 26 của bạn đã đạt độ hoàn thiện 100%!

---

## Cứu hộ & Bảo trì khi cập nhật macOS trong tương lai

- **Khi Apple tung bản cập nhật macOS Tahoe 26.x mới làm thay đổi Kernel ABI của `AirportItlwm_Tahoe.kext`**:
  1. Nếu đã cài sẵn Xcode, chỉ cần chạy `bash patches/build-airportitlwm-tahoe.sh` rồi chạy `sudo bash scripts/04-cap-nhat-wifi-dualboot-ax210.sh` để biên dịch và nạp kext mới khớp Kernel ABI mới.
  2. Hoặc nếu cần mạng ngay lập tức để tải Xcode, chạy `sudo bash scripts/07-khoi-phuc-wifi-heliport.sh` để chuyển tạm sang `itlwm.kext` + `HeliPort` trong 3 giây.
- **Muốn bật lại chế độ chạy chữ log (`-v`) cố định**:
  ```bash
  sudo bash scripts/06-khoi-phuc-boot-log-verbose.sh
  ```
- **Muốn đổi hình nền 4K khác cho màn hình chọn Hệ điều hành**:
  Chuẩn bị 2 ảnh PNG `bg_1x.png` (`1920x1080`) và `bg_2x.png` (`3840x2160`), sau đó đóng gói bằng công cụ đi kèm:
  ```bash
  ./tools/icnspack/icnspack EFI/OC/Resources/Image/Acidanthera/GoldenGate/Background.icns bg_1x.png bg_2x.png
  ```

---

## Lời cảm ơn (Credits)
- **Acidanthera** (`OpenCorePkg`, `OpenCanopy`, `OcBinaryData`, `Lilu`, `VirtualSMC`, `WhateverGreen`, `AppleALC`, `NVMeFix`, `RestrictEvents`)
- **Dortania** (`AMD Vanilla OpenCore Patches` & OpenCore Install Guide)
- **OpenIntelWireless & laobamac** (`itlwm` / `AirportItlwm-Tahoe`, `IntelBluetoothFirmware`)
- **Project 1401 / NullMoth** (NVIDIA Ampere RTX 30-series driver cho macOS)
- **USBToolBox & Mieze** (`USBToolBox`, `RTL812xLucy`)
