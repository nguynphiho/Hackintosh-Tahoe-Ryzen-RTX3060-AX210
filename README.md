# Hackintosh macOS Tahoe 26 — AMD Ryzen (AM5) + NVIDIA RTX 3060 + Intel Wi-Fi 6E AX210 (Dual-Boot Windows 11)

Bộ cấu hình **OpenCore `1.0.9`** hoàn chỉnh (tích hợp kiến trúc **Config 2 Giai đoạn** chống treo & chống đen màn hình) cùng hệ thống **Scripts tự động hóa trên cả Windows 11 lẫn macOS** để cài đặt và vận hành **macOS Tahoe `26.x` (`Darwin 25.x`)** ổn định như Mac thật trên cấu hình PC **AMD Ryzen + Card rời NVIDIA RTX 3060 + Wi-Fi/Bluetooth Intel AX210** song song **Windows 11**.

Repository này hỗ trợ trọn vẹn **CẢ 2 LỘ TRÌNH**:
- **Lộ trình 1**: **Cài mới hoàn toàn từ con số 0 ngay trên máy Windows 11** (chưa từng cài Hackintosh, không cần mượn máy Mac).
- **Lộ trình 2**: **Nâng cấp trực tiếp từ macOS Sequoia 15 lên macOS Tahoe 26** giữ nguyên dữ liệu.

> **Dành cho AI Coding Agent (Antigravity / Claude Code / Cursor / Codex):** Nếu bạn đang nhờ AI đọc repo này để tự động tạo bộ cài, kiểm tra phần cứng hoặc sửa lỗi cho bạn, hãy bảo AI đọc tệp **[`AI_AGENT_GUIDE.md`](./AI_AGENT_GUIDE.md)**.

---

## Điểm nổi bật của bản dựng này

1. **Kiến trúc Config 2 Giai đoạn (`Stage 1` & `Stage 2`) — Không bao giờ treo hay đen màn hình**:
   - **`config-stage1-cai-moi.plist`**: Mở framebuffer gốc `IONDRVSupport` + bật `-nvoff -v` để boot USB cài mới macOS Tahoe từ Windows lên hình 100%, thấy rõ tiến trình cài đặt.
   - **`config-stage2-full-rtx3060.plist` (`config.plist`)**: Chặn `IONDRVSupport` + tích hợp sẵn **trọn bộ 6 chốt chặn chống lỗi "Màn hình đen cùng con trỏ chuột"** trên RTX 3060.
2. **Full tăng tốc đồ họa Metal 3 trên NVIDIA GeForce RTX 3060 (12GB)**: Hỗ trợ tần số quét cao (`100Hz+` / HiDPI), xuất âm thanh HDMI/DisplayPort 8 kênh và Realtek ALC897 qua **Project 1401 (`NullMoth v2.7.2+`)**, kèm cơ chế tự động tải gói chính chủ (kiểm tra SHA-256) và gom gọn các tiến trình nền dưới `1401.app`.
3. **Giữ nguyên niêm phong hệ thống Apple (`Sealed: Yes`)**: Không dùng OCLP Root Patch can thiệp vào phân vùng gốc macOS Tahoe — bảo mật tuyệt đối, không vỡ snapshot APFS.
4. **Wi-Fi Native Apple gốc cho Intel AX210 (`AirportItlwm_Tahoe.kext`) + Bản vá C++ Dual-Boot độc quyền**: Bắt Wi-Fi trực tiếp trên thanh Menu Bar gốc của Apple **không cần HeliPort** (hoạt động ngay từ màn hình cài đặt USB!), đồng thời tích hợp bản vá nhân C++ (`iwx_quiesce_warm_boot_hw` + **PCIe FLR**) khắc phục triệt để lỗi mất Wi-Fi khi bấm **Restart** ấm từ Windows 11 sang macOS.
5. **Giao diện chọn Hệ điều hành đồ họa 4K (`OpenCanopy` + `GoldenGate`) & Silent Boot**: Chọn **Macintosh HD / Windows** bằng **Chuột** hoặc bàn phím trên nền núi 4K sắc nét, tự động vào macOS sau 5 giây với **Logo Táo** sạch sẽ (tắt hoàn toàn dòng chữ log `-v`).

---

## Cấu hình phần cứng chuẩn & Khả năng tương thích mở rộng

| Thành phần | Phần cứng kiểm chứng thực tế | Driver / Kext xử lý | Ghi chú nếu máy bạn khác linh kiện |
| :--- | :--- | :--- | :--- |
| **CPU** | AMD Ryzen 5 7500F (6 nhân / 12 luồng, AM5) | AMD Vanilla Patches (`Algrey Fix PAT`) | Script Windows/macOS tự động chỉnh cho CPU Ryzen **6 / 8 / 12 / 16 nhân** |
| **RAM** | 32 GB DDR5 | `RestrictEvents.kext` + `MacPro7,1` | Hỗ trợ mọi dung lượng DDR4 / DDR5 |
| **GPU** | NVIDIA GeForce RTX 3060 12GB (`0x10de:0x2504`) | `WhateverGreen` (`gfxrst=4`) + **NullMoth `v2.7.2+`** | Hỗ trợ GTX 16xx, RTX 20xx (tự thêm `nvrmsettle=10000`), RTX 30xx / 40xx / 50xx |
| **Wi-Fi** | Intel Wi-Fi 6E AX210 (`pci8086,2725`) | `AirportItlwm_Tahoe.kext` (đã vá C++ FLR) | Hỗ trợ dòng card Intel AX200 / AX201 / AX210 / AX211 |
| **Bluetooth** | Intel AX210 USB Bluetooth | `IntelBluetoothFirmware` + `BlueToolFixup` | Hoạt động ổn định trên Tahoe 26 |
| **LAN** | Realtek 2.5GbE Ethernet | `RTL812xLucy.kext` | Nếu dùng LAN Intel I225-V/I226-V, thêm `AppleIGC.kext` |
| **Âm thanh** | Realtek ALC897 + NVIDIA HDMI/DP | `AppleALC.kext` + NullMoth Audio | Đầu ra loa, tai nghe & Micro đầy đủ |
| **Ổ cứng** | 1TB Kingston NV2 PCIe 4.0 NVMe | `NVMeFix.kext` (GPT Dual-Boot Win 11 + macOS) | Tránh ổ Samsung PM981 / PM991 (kén macOS) |

> **Lưu ý về cổng USB nếu khác Mainboard:** File `UTBMap.kext` đi kèm được ánh xạ cho mainboard AM5 chuẩn. Nếu sang mainboard khác bị thiếu cổng USB, bạn có thể tạo lại `UTBMap.kext` riêng bằng công cụ [USBToolBox trên Windows](https://github.com/USBToolBox/tool/releases) (hoặc bằng công cụ `1401-Windows`) rồi thay vào `EFI/OC/Kexts/UTBMap.kext`.

---

## Nguồn tải chính thức Project 1401 / NullMoth (Driver NVIDIA Metal 3)

Do bộ cài driver NVIDIA có dung lượng lớn (`~255 MB`), Git không đính kèm sẵn file nén `.tar.gz`. Dưới đây là **đường dẫn chính thức 100%** từ nhà phát triển **NullMoth Systems**:

| Gói phần mềm | Tệp cần tải | Đường dẫn tải chính thức | Khi nào dùng? |
| :--- | :--- | :--- | :--- |
| **Trang chủ dự án** | Thông tin & tài liệu gốc | https://nullmothsystems.com/ | Tham khảo thông tin phiên bản |
| **Driver NVIDIA cho macOS + App `1401`** *(Bắt buộc cho RTX 3060)* | `1401-Mac-2.7.2.dmg` (`~3 MB`) **và** `nullmoth-nvidia-2.7.2.tar.gz` (`~252 MB`) | https://github.com/nullmoth/nvidia-macos-driver/releases/latest | Tải sẵn trên Windows bỏ vào USB để cài Offline, **HOẶC** để `scripts/02-cai-driver-rtx3060-sau-tahoe.sh` **tự động tải & kiểm tra SHA-256** ngay trên macOS! |
| **Công cụ `1401` cho Windows** *(Tùy chọn)* | `1401-Windows-2.7.2.zip` (`~272 MB`) | https://github.com/nullmoth/1401/releases/latest | Dùng nếu bạn chưa cài Python trên Windows và muốn tạo bộ cài USB bằng giao diện đồ họa |

---

## Cấu trúc thư mục Repository

```text
Hackintosh-Tahoe-Ryzen-RTX3060-AX210/
├── README.md                                         # Hướng dẫn toàn diện từ con số 0 trên Windows đến hoàn thiện
├── AI_AGENT_GUIDE.md                                 # Playbook kỹ thuật chi tiết cho AI Agent thực thi tự động
├── AGENTS.md / CLAUDE.md                             # Điểm vào tự động cho Antigravity, Cursor, Codex, Claude Code
├── EFI/                                              # Bộ OpenCore 1.0.9 hoàn chỉnh (đã làm sạch Serial mẫu an toàn)
│   ├── Boot/BOOTx64.efi
│   └── OC/
│       ├── config.plist                              # Cấu hình chính (mặc định Stage 2 Full RTX 3060 + Silent Boot)
│       ├── config-stage1-cai-moi.plist               # Cấu hình Stage 1 (Dùng khi tạo USB cài mới từ Windows)
│       ├── config-stage2-full-rtx3060.plist          # Bản lưu tham chiếu chuẩn Stage 2 (Chống đen màn hình 100%)
│       └── ACPI / Drivers / Kexts / Resources / Tools
├── patches/                                          # Mã nguồn C++ vá lỗi mất Wi-Fi Dual-Boot Windows <-> macOS
│   ├── itlwm-tahoe-ax210-warm-reboot.patch
│   ├── build-airportitlwm-tahoe.sh
│   └── README.md
├── scripts/
│   ├── windows/                                      # BỘ SCRIPTS CHẠY TRỰC TIẾP TRÊN WINDOWS 10/11
│   │   ├── 01-tai-macos-tahoe-recovery.cmd           # Tải bộ cài macOS Tahoe 26 Recovery chính gốc từ Apple
│   │   ├── 02-chuan-bi-efi-cai-moi-windows.cmd       # Tự sinh SMBIOS + chỉnh số nhân Ryzen + nạp Stage 1 + chép ra USB
│   │   ├── prepare-efi-stage1.ps1                    # Nhân xử lý XML & kiểm định ocvalidate.exe cho Windows
│   │   └── fix-wifi-dualboot-windows11.cmd           # Tắt Fast Startup / Hiberboot & WoWLAN bên Windows 11
│   ├── 00-tao-smbios-rieng.sh                        # Tạo Serial / MLB / UUID / ROM riêng trên macOS / Linux
│   ├── 01-chuan-bi-len-tahoe.sh                      # Chuẩn bị EFI khi nâng cấp từ macOS Sequoia 15 lên Tahoe 26
│   ├── 02-cai-driver-rtx3060-sau-tahoe.sh            # Tự tải/cài NullMoth RTX 3060 + nâng EFI lên Stage 2 + gom 1401
│   ├── 03-kich-hoat-wifi-native-ax210.sh             # Bật Wi-Fi Native Apple trên Tahoe 26 (gỡ HeliPort & OCLP cũ)
│   ├── 04-cap-nhat-wifi-dualboot-ax210.sh            # Cập nhật nhanh kext vá lỗi Restart từ Windows sang macOS
│   ├── 05-bat-giao-dien-opencanopy-ui.sh             # Bật UI chọn HĐH 4K dùng chuột + tắt log (-v) + khóa mặc định macOS
│   ├── 06-khoi-phuc-boot-log-verbose.sh              # Bật lại chữ log (-v) khi cần gỡ lỗi
│   ├── 07-khoi-phuc-wifi-heliport.sh                 # Chuyển dự phòng về itlwm + HeliPort chỉ với 1 lệnh
│   ├── 08-kiem-tra-suc-khoe-hackintosh.sh            # Kiểm tra toàn diện sức khỏe hệ thống (Metal 3, BAR1, Wi-Fi, Sealed)
│   ├── 09-sua-loi-man-hinh-den-con-tro-chuot.sh      # Chẩn đoán & tự sửa 6 nguyên nhân lỗi màn hình đen trỏ chuột
│   └── 10-chep-efi-usb-vao-nvme-dualboot.sh          # Chép EFI từ USB vào ổ cứng NVMe cạnh Windows 11 an toàn 100%
└── tools/                                            # Công cụ gốc OpenCore 1.0.9 cho macOS, Windows (.exe) & Linux
    ├── macserial/
    ├── ocvalidate/
    ├── icnspack/
    └── macrecovery/
```

---

## PHẦN I: HƯỚNG DẪN CÀI MỚI TỪ CON SỐ 0 TRÊN WINDOWS 11 (DUAL-BOOT)

Dành cho bạn đang dùng PC Windows 11 bình thường và muốn cài thêm **macOS Tahoe 26** chạy song song trên cùng 1 ổ NVMe (hoặc trên ổ SSD thứ 2) mà **không cần mượn máy Mac**.

### Bước 1: Chia phân vùng cho macOS ngay trên Windows 11 (Không mất dữ liệu)
1. Nhấn **`Win + X`** → chọn **Disk Management**:
   - Kiểm tra phân vùng **EFI System Partition**: Bộ `EFI` của repo chiếm khoảng `~32 MB` nên vẫn chép vừa vào phân vùng EFI `100 MB` mặc định của Windows, nhưng để dư dả lâu dài, khuyến nghị phân vùng EFI từ **`200 MB – 300 MB`** (có thể mở rộng miễn phí bằng *NIUBI Partition Editor Free* hoặc *MiniTool Partition Wizard*).
   - Chuột phải vào phân vùng ổ cứng còn trống nhiều dung lượng (ví dụ ổ `C:` hoặc `D:`) → chọn **Shrink Volume** → rút ra tối thiểu **`80,000 MB` – `150,000 MB`** (`80 GB – 150 GB+`) cho macOS.
   - Chuột phải vào vùng trống *Unallocated* vừa tạo → **New Simple Volume** → chọn định dạng **`ExFAT`**, đặt tên nhãn (**Volume label**) là **`MACOS_INSTALL`** → Finish. *(Đặt tên rõ ràng như vậy giúp lát vào bộ cài macOS nhận diện đúng 100%, không bao giờ xóa nhầm ổ Windows!).*
2. Chuột phải vào tệp **`scripts\windows\fix-wifi-dualboot-windows11.cmd`** trong repo → chọn **Run as administrator** để tắt *Windows Fast Startup* ngay từ đầu (tránh Windows khóa cứng bảng phân vùng ổ cứng và card Wi-Fi AX210).

---

### Bước 2: Tạo USB cài đặt macOS Tahoe 26 trên Windows 11
Chuẩn bị 1 chiếc **USB từ `16 GB – 32 GB`** (lưu ý dữ liệu cũ trên USB sẽ bị xóa). Tải repository này về Windows (`git clone` hoặc bấm **Code → Download ZIP** trên GitHub rồi giải nén ra màn hình Desktop). Bạn có thể chọn **1 trong 2 cách** dưới đây:

#### Cách 2A (Khuyên dùng): Tạo tự động bằng bộ Script Windows đi kèm Repo
1. **Format USB chuẩn `FAT32 + GPT`**:
   - Tải công cụ miễn phí [Rufus](https://rufus.ie/) → Mở Rufus, chọn đúng chiếc USB của bạn.
   - Mục **Boot selection**: chọn **`Non bootable`**.
   - Mục **Partition scheme**: chọn **`GPT`**.
   - Mục **File system**: chọn **`FAT32`** (hoặc **`Large FAT32`**) → Bấm **START** → Đợi 5 giây báo *READY* thì đóng Rufus.
2. **Tải bộ cài macOS Tahoe 26 Recovery chính gốc từ Apple**:
   - Mở thư mục `scripts\windows\` → Đúp chuột chạy **`01-tai-macos-tahoe-recovery.cmd`**.
   - Nhập ký tự ổ USB (ví dụ `E`) rồi nhấn `Enter` → Script sẽ gọi `macrecovery.py` tải thẳng gói **`com.apple.recovery.boot`** (`~800 MB`) từ máy chủ Apple vào gốc USB `E:\com.apple.recovery.boot\`.
   - *(Lưu ý: Nếu Windows của bạn chưa cài Python 3, mở CMD gõ `winget install -e --id Python.Python.3.12` chờ 20 giây là xong, hoặc dùng Cách 2B bên dưới).*
3. **Tự động sinh mã SMBIOS riêng, chỉnh số nhân CPU Ryzen & chép EFI Stage-1 ra USB**:
   - Đúp chuột chạy tiếp **`02-chuan-bi-efi-cai-moi-windows.cmd`**.
   - Nhập ký tự ổ USB (`E`) khi được hỏi. Chỉ trong 3 giây, script tự động:
     - Nạp cấu hình **Stage 1 (`config-stage1-cai-moi.plist`)** mở framebuffer gốc `IONDRVSupport` + bật `-nvoff -v` (đảm bảo **0% nguy cơ màn hình đen** khi boot USB cài mới!).
     - Sinh bộ Serial / MLB / UUID / ROM `MacPro7,1` độc nhất vô nhị cho máy bạn.
     - Tự động nhận diện số nhân vật lý CPU AMD Ryzen của máy và vá chuẩn cả 4 dòng `cpuid_cores_per_package`.
     - Kiểm định bằng `ocvalidate.exe` (`No issues found!`) và chép thẳng `EFI\` cùng thư mục hậu cài đặt `HACKINTOSH-TOOLS\` sang USB!
4. **Chép sẵn gói Driver RTX 3060 vào USB (Khuyên làm để cài Offline cực nhanh)**:
   - Tải 2 tệp **`1401-Mac-2.7.2.dmg`** và **`nullmoth-nvidia-2.7.2.tar.gz`** tại [NullMoth Releases](https://github.com/nullmoth/nvidia-macos-driver/releases/latest) và chép vào thư mục **`E:\HACKINTOSH-TOOLS\`** trên USB.

#### Cách 2B (Thay thế nếu không muốn cài Python): Dùng phần mềm `1401-Windows` của NullMoth
1. Tải **`1401-Windows-2.7.2.zip`** tại [NullMoth 1401 Releases](https://github.com/nullmoth/1401/releases/latest), giải nén và chạy `1401.exe` với quyền Administrator để phần mềm tự động tải macOS Tahoe và ghi ra USB (công cụ này cũng có thể giúp bạn quét tạo `UTBMap.kext` nếu dùng mainboard khác).
2. Sau khi `1401.exe` ghi xong USB, đúp chuột chạy **`scripts\windows\02-chuan-bi-efi-cai-moi-windows.cmd`** trong repo này để ghi đè bộ `EFI` Stage-1 đã tối ưu sẵn **Wi-Fi Native AX210 Dual-Boot + OpenCanopy 4K** lên USB *(nhớ giữ lại `UTBMap.kext` riêng nếu mainboard của bạn khác mẫu)*.

---

### Bước 3: Thiết lập BIOS Bo mạch chủ (CỰC KỲ QUAN TRỌNG)
Khởi động lại PC, nhấn `Del` / `F2` vào BIOS và kiểm tra đúng các mục sau:

- **BẮT BUỘC BẬT (`Enabled`)**:
  - **`Above 4G Decoding`**: `Enabled`
  - **`Resizable BAR` (`Re-Size BAR Support` / `Smart Access Memory`)**: **`Enabled`**
    > **LƯU Ý SỐNG CÒN CHO RTX 3060:** Với driver NVIDIA NullMoth, bạn **PHẢI BẬT `Resizable BAR = Enabled`** trong BIOS để mở cửa sổ bộ nhớ PCIe **`BAR1 = 8 GB`**. Nếu để `Disabled`, `BAR1` bị bóp nghẹt ở `256 MB` sẽ gây tràn bộ nhớ ngay màn hình đăng nhập dẫn đến lỗi **màn hình đen chỉ hiện con trỏ chuột**! *(Trong `config.plist`, `ResizeGpuBars = -1` và `ResizeAppleGpuBars = 0` đã được cấu hình chuẩn để giữ nguyên BAR 8GB của BIOS mà không làm treo UEFI).*
  - **`EHCI/XHCI Hand-off`**: `Enabled`
  - **`SATA Mode`**: `AHCI`
- **BẮT BUỘC TẮT (`Disabled`)**:
  - **`CSM (Compatibility Support Module)`**: `Disabled`
  - **`Secure Boot`**: `Disabled` *(hoặc chọn OS Type: `Other OS`)*
  - **`Fast Boot`**: `Disabled`
  - **`Serial / COM Port`**: `Disabled` *(nếu có)*

Lưu BIOS (`F10`) và nhấn phím tắt chọn Boot Menu (`F12` / `F11` / `F8` tùy hãng mainboard) → Chọn khởi động vào **`UEFI: <Tên USB của bạn>`**.

---

### Bước 4: Format APFS & Cài đặt macOS Tahoe 26
1. Tại màn hình giao diện đồ họa **OpenCanopy 4K**, dùng chuột click vào biểu tượng **`Recovery` / `macOS Base System` (hoặc `Install macOS Tahoe`)**. Màn hình sẽ chạy dòng chữ kiểm tra phần cứng khoảng 1–2 phút rồi vào thẳng cửa sổ **macOS Recovery**.
2. **Kết nối Internet** (nếu dùng bộ cài Recovery Online):
   - Cắm dây mạng LAN (`RTL812xLucy` tự nhận ngay), **HOẶC** nhìn lên **góc trên bên phải màn hình** bấm vào biểu tượng **Wi-Fi** để kết nối mạng Wi-Fi (nhờ `AirportItlwm_Tahoe.kext` đã nạp sẵn trong EFI!).
3. **Định dạng phân vùng cài đặt sang APFS**:
   - Chọn **Disk Utility** → Continue.
   - Bấm nút **`View` (góc trên bên trái)** → chọn **`Show All Devices`**.
   - Nhìn cột bên trái, chọn đúng phân vùng **`MACOS_INSTALL`** đã chia ở Bước 1 (**kiểm tra kỹ tên và dung lượng, tuyệt đối không chạm vào phân vùng NTFS của Windows!**).
   - Bấm nút **Erase** ở thanh công cụ phía trên:
     - **Name**: `Macintosh HD`
     - **Format**: `APFS`
   - Bấm **Erase** → Đợi báo *Done* rồi đóng cửa sổ Disk Utility (`Cmd/Win + Q`).
4. **Tiến hành cài đặt macOS Tahoe**:
   - Chọn **Reinstall macOS Tahoe** → Continue → Chọn ổ **`Macintosh HD`**.
   - Trong quá trình cài đặt, máy sẽ **tự động khởi động lại 3 đến 4 lần**. Ở mỗi lần khởi động lại, cứ cắm nguyên USB để OpenCore tự động chọn tiếp mục `macOS Installer` (và cuối cùng là `Macintosh HD`) cho tới khi hiện màn hình chào mừng *Select Your Country or Region*!

---

### Bước 5: Chạy 4 Lệnh Hoàn Thiện Sau Khi Vào Màn Hình Chính macOS Tahoe
Sau khi tạo tài khoản và vào tới Desktop của macOS Tahoe (lúc này máy đang chạy hình ảnh cơ bản Stage 1 để an toàn tuyệt đối), mở ứng dụng **Terminal** và chạy lần lượt 4 lệnh sau từ thư mục `HACKINTOSH-TOOLS` trên USB:

```bash
cd /Volumes/*/HACKINTOSH-TOOLS

# 1. Cài Driver NVIDIA RTX 3060 (Full Metal 3 + Audio) & tự động nâng EFI lên Stage 2
#    (Tự dùng file trong USB/Downloads nếu đã chép sẵn, hoặc tự tải từ GitHub NullMoth + check SHA-256!)
sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh

# 2. Kích hoạt chuẩn Wi-Fi Native Apple & Bản vá C++ chống mất Wi-Fi khi Restart từ Windows 11
sudo bash scripts/03-kich-hoat-wifi-native-ax210.sh

# 3. Bật giao diện chọn HĐH 4K dùng chuột + Tắt chữ log (-v) + Khóa mặc định mở macOS
sudo bash scripts/05-bat-giao-dien-opencanopy-ui.sh

# 4. Chép bộ OpenCore hoàn chỉnh từ USB vào ổ cứng NVMe (giữ nguyên 100% EFI/Microsoft của Windows 11!)
sudo bash scripts/10-chep-efi-usb-vao-nvme-dualboot.sh
```

- Mở **System Settings → Privacy & Security**, bấm **Allow** nếu macOS hỏi xác nhận phần mở rộng hệ thống.
- Rút USB ra khỏi máy, bấm **Restart**, vào BIOS đặt ưu tiên khởi động số 1 (`Boot Option #1`) là **`UEFI OS` / `OpenCore`** trên ổ cứng NVMe — từ nay mỗi lần bật máy sẽ lên màn hình núi 4K sắc nét cho phép chọn cả **Macintosh HD** lẫn **Windows 11**!

---

## PHẦN II: HƯỚNG DẪN NÂNG CẤP TỪ MACOS SEQUOIA 15 LÊN TAHOE 26

Nếu máy bạn đã cài sẵn Hackintosh **macOS Sequoia 15** và muốn nâng cấp lên **macOS Tahoe 26**:

1. Tạo SMBIOS riêng (nếu dùng bộ EFI của repo lần đầu) hoặc chạy script chuẩn bị EFI Dual-Kernel trên Sequoia:
   ```bash
   sudo bash scripts/01-chuan-bi-len-tahoe.sh
   ```
   *(Tự động sao lưu EFI ra Desktop, khóa các kext OCLP cũ của Sequoia ở `Darwin 24.x` để không gây Kernel Panic trên Tahoe `25.x`, và nạp sẵn `AirportItlwm_Tahoe.kext`).*
2. Nếu trên Sequoia đang chạy driver NVIDIA NullMoth, mở ứng dụng **`1401.app`** bấm **Prepare for macOS update** (hoặc tải bản cập nhật qua *System Settings → Software Update* / *Install macOS Tahoe.app*) và để máy tự nâng cấp lên Tahoe 26.
3. Sau khi vào macOS Tahoe 26, chạy lần lượt các script `02`, `03`, `05` và kiểm tra bằng `bash scripts/08-kiem-tra-suc-khoe-hackintosh.sh`.

---

## PHẦN III: CONFIG CHỐNG & SỬA LỖI "MÀN HÌNH ĐEN CÙNG CON TRỎ CHUỘT" (RTX 3060)

> **Câu hỏi thường gặp:** *"Bộ `config.plist` trong repo đã có sẵn thiết lập sửa lỗi vào macOS bị màn hình đen thui chỉ thấy mỗi con trỏ chuột di chuyển chưa?"*
> **Trả lời:** **ĐÃ TÍCH HỢP SẴN 100%!** Toàn bộ 6 nguyên nhân gây hiện tượng màn hình đen chỉ hiện con trỏ chuột trên card rời NVIDIA + CPU AMD Ryzen + macOS Tahoe 26 đều đã được khóa chặt trong `EFI/OC/config.plist` (`Stage 2`) và kiểm soát tự động bởi `scripts/09-sua-loi-man-hinh-den-con-tro-chuot.sh`.

### Bảng 6 nguyên nhân gây "Màn hình đen + Con trỏ chuột" & Cách Repo này đã xử lý

| # | Nguyên nhân gốc rễ | Hiện tượng khi gặp lỗi | Thiết lập đã tích hợp sẵn trong Repo |
| :-: | :--- | :--- | :--- |
| **1** | `WindowServer` (binary gốc của Apple) từ chối nạp gói Metal ad-hoc của NullMoth | Vào tới màn hình đăng nhập tối đen hoàn toàn, chỉ di chuyển được con trỏ chuột trắng/màu | Nạp `AMFIPass.kext` ngay sau `Lilu.kext` + `-lilubetaall` + `amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0` + `csr-active-config = 430A0000` (`0x0A43`) + `SecureBootModel = Disabled` |
| **2** | Tắt `Resizable BAR` trong BIOS làm cửa sổ PCIe `BAR1` chỉ còn `256 MB` | Tràn bộ nhớ `BAR1` ngay lúc vẽ màn hình đăng nhập → màn hình đen, chỉ còn trỏ chuột | Bật **`Above 4G Decoding` + `Resizable BAR = Enabled`** trong BIOS (mở `BAR1 = 8 GB`), kết hợp `ResizeGpuBars = -1` & `ResizeAppleGpuBars = 0` trong OpenCore |
| **3** | Xung đột framebuffer gốc `com.apple.iokit.IONDRVSupport` | Chặn quá sớm khi cài USB thì mất hình lúc cài; quên chặn sau khi cài NullMoth thì `IONDRV` cướp màn hình số 0 gây đen màn hình | Tách rõ **Stage 1** (`Enabled = False` lúc cài USB) và **Stage 2** (`Enabled = True`, `MaxKernel = ""` sau khi cài NullMoth) |
| **4** | Đụng độ chuyển cảnh KMS Smooth Handoff & Boot-Screen Copy của `WhateverGreen` | Màn hình nháy tắt đen ngòm hoặc tự khởi động lại ngay khi mở `NVRMFB` | Tích hợp sẵn `-nvkmsnosmooth nvfb=1 nvaccel=1 nvfbheads=4 gfxrst=4` (và tự thêm `nvrmsettle=10000` nếu phát hiện card GTX 16xx / RTX 20xx) |
| **5** | Bật nhầm bản vá nhân AMD `Shaneee - Fix PAT` thay vì `Algrey` | Driver NVIDIA dừng ở `RmInitAdapter failed!` dù đã có `BAR1 = 8 GB` | Bật cứng **`Algrey / Zormeister - Fix PAT = True`**, tắt **`Shaneee - Fix PAT = False`**, bật `DisableVariableWrite = True` cho AM5 |
| **6** | Cập nhật macOS mới làm `AuxiliaryKernelExtensions.kc` mất kext `NVAccel` | Mất tăng tốc Metal hoặc treo màn hình đen sau khi update macOS | Script `09` tự động kiểm tra và đóng gói lại `AuxiliaryKernelExtensions.kc` bằng `kmutil` |

### Cách cứu hộ trong 30 giây nếu bạn lỡ chỉnh sai BIOS / update macOS bị màn hình đen trỏ chuột

1. Khởi động lại máy, tại màn hình chọn hệ điều hành **OpenCanopy 4K**, nhấn phím **`Space` (Phím Cách)** trên bàn phím để hiện các công cụ cứu hộ ẩn.
2. Dùng chuột hoặc phím mũi tên chọn **`1401: Start once without NVIDIA driver`** → Sau đó chọn tiếp **`Macintosh HD`**. Máy sẽ tạm bỏ qua driver NVIDIA trong 1 lần boot để đưa bạn vào thẳng màn hình Desktop macOS ngay lập tức!
3. Mở **Terminal** và chạy lệnh tự động chẩn đoán & sửa sạch cả 6 nguyên nhân:
   ```bash
   sudo bash scripts/09-sua-loi-man-hinh-den-con-tro-chuot.sh
   ```
4. Khởi động lại máy (kiểm tra thêm BIOS đã bật `Resizable BAR = Enabled` chưa) là lên lại Full Metal 3 mượt mà!

---

## Phím tắt tại màn hình OpenCanopy & Lệnh Kiểm tra Sức khỏe

### Phím tắt tại màn hình chọn Hệ điều hành (`OpenCanopy`)
- **Click Chuột** hoặc **`←` / `→` + `Enter`**: Chọn khởi động **Macintosh HD** hoặc **Windows**.
- **`Ctrl + Enter`** (hoặc **`Ctrl + Click chuột`**): Đặt hệ điều hành đang chọn làm mặc định.
- **Phím `Space` (Phím Cách)**: Hiện đầy đủ các công cụ ẩn (`Recovery`, `Reset NVRAM`, `1401: Start once without NVIDIA driver`, `1401: Remove NVIDIA driver`).
- **Giữ `Win/Cmd + V`** khi chọn macOS: Xem dòng chữ log tạm thời trong đúng 1 lần boot đó.

### Kiểm tra sức khỏe toàn diện hệ thống (Chạy bất cứ lúc nào không cần `sudo`)
```bash
bash scripts/08-kiem-tra-suc-khoe-hackintosh.sh
```
Khi tất cả các hạng mục đều hiện **`[PASS]`** (`Sealed: Yes`, `Metal Support: Metal 3`, `PCIe BAR1 mở rộng`, `com.zxystd.AirportItlwm`, `IntelBluetoothFirmware`, `Silent Boot`, `OCBt0080 Default OS`, và cả 3 file `config*.plist` đều đạt `ocvalidate: No issues found`), hệ thống của bạn đang ở trạng thái hoàn hảo nhất!

---

## Bảo trì khi cập nhật macOS trong tương lai

- **Khi Apple phát hành macOS Tahoe `26.x` mới làm thay đổi Kernel ABI của Wi-Fi**:
  - Chạy `bash patches/build-airportitlwm-tahoe.sh` rồi `sudo bash scripts/04-cap-nhat-wifi-dualboot-ax210.sh` (nếu đã cài Xcode), **hoặc** chạy `sudo bash scripts/07-khoi-phuc-wifi-heliport.sh` để dùng ngay `itlwm + HeliPort` dự phòng trong 3 giây.
- **Muốn bật lại chữ log (`-v`) cố định khi khởi động**:
  ```bash
  sudo bash scripts/06-khoi-phuc-boot-log-verbose.sh
  ```
- **Muốn đổi hình nền 4K riêng cho màn hình chọn Hệ điều hành**:
  ```bash
  ./tools/icnspack/icnspack EFI/OC/Resources/Image/Acidanthera/GoldenGate/Background.icns bg_1x.png bg_2x.png
  ```

---

## Lời cảm ơn (Credits)
- **Acidanthera** (`OpenCorePkg`, `OpenCanopy`, `OcBinaryData`, `Lilu`, `VirtualSMC`, `WhateverGreen`, `AppleALC`, `NVMeFix`, `RestrictEvents`)
- **Dortania** (`AMD Vanilla OpenCore Patches` & OpenCore Install Guide)
- **OpenIntelWireless & laobamac** (`itlwm` / `AirportItlwm-Tahoe`, `IntelBluetoothFirmware`)
- **Project 1401 / NullMoth Systems** (NVIDIA Modern GPU Metal 3 driver & `1401` toolsuite cho macOS)
- **USBToolBox & Mieze** (`USBToolBox`, `RTL812xLucy`)
