# AI Agent Autonomous Execution Guide (`AI_AGENT_GUIDE.md`)

Tài liệu này được thiết kế chuyên biệt cho các **AI Coding / System Agents** (**Google Antigravity, Claude Code, Cursor, OpenAI Codex, Windsurf**) khi người dùng mở repository này và yêu cầu AI hỗ trợ cài đặt, nâng cấp, điều chỉnh cấu hình phần cứng, vá lỗi Wi-Fi Dual-Boot, hoặc bật giao diện OpenCanopy trên máy Hackintosh **macOS Tahoe 26 (`Darwin 25.x`)**.

---

## 1. Bất biến An toàn Tuyệt đối (CRITICAL SAFETY INVARIANTS)

Trước khi thực hiện bất kỳ thao tác ghi nào lên hệ thống hoặc phân vùng EFI của người dùng, AI Agent **BẮT BUỘC** tuân thủ 8 quy tắc bất biến sau:

1. **KHÔNG BAO GIỜ dùng nguyên Serial/MLB/UUID mẫu (`W00000000001`) cho máy người dùng**:
   - Nếu `PlatformInfo -> Generic -> SystemSerialNumber` đang là `W00000000001`, AI phải chạy `bash scripts/00-tao-smbios-rieng.sh` để sinh bộ SMBIOS duy nhất.
   - Nếu đang đẩy thay đổi lên Git công khai (`git push`), AI phải kiểm tra chắc chắn `SystemSerialNumber`, `MLB`, `SystemUUID`, `ROM` trong `EFI/OC/config.plist` đã được làm sạch về placeholder, **tuyệt đối không làm lộ Serial thật của người dùng lên GitHub**.
2. **KHÔNG BAO GIỜ chạy OCLP Root Patch trên macOS Tahoe 26 khi dùng Project 1401 / NullMoth (RTX 3060)**:
   - Ổ hệ thống `Macintosh HD` phải luôn giữ trạng thái **`Sealed: Yes`** (`diskutil info / | grep Sealed`).
   - Wi-Fi Native cho Intel AX210 trên Tahoe 26 đạt được thông qua `AirportItlwm_Tahoe.kext` nạp từ `EFI/OC/Kexts` (`MinKernel = 25.0.0`, `MaxKernel = 25.99.99`), hoàn toàn không đụng chạm phân vùng gốc.
3. **KHÔNG BAO GIỜ nạp đồng thời `itlwm.kext` và `AirportItlwm_Tahoe.kext`**:
   - Khi `AirportItlwm_Tahoe.kext` có `Enabled = True`, `itlwm.kext` **phải** có `Enabled = False` (và các kext Sequoia cũ `IOSkywalkFamily.kext`, `IO80211FamilyLegacy.kext`, `AirportItlwm.kext` phải bị khóa cứng ở `MaxKernel = 24.99.99`).
4. **KHÔNG BAO GIỜ trộn lẫn các file `.efi` của OpenCore khác phiên bản build**:
   - `EFI/Boot/BOOTx64.efi`, `EFI/OC/OpenCore.efi`, `EFI/OC/Drivers/OpenRuntime.efi`, `EFI/OC/Drivers/ResetNvramEntry.efi`, và `EFI/OC/Drivers/OpenCanopy.efi` phải đến từ **cùng một bản build** (`OpenCore 1.0.9 - commit f4a7e45`).
   - Mã băm chuẩn trong repo này:
     - `EFI/OC/OpenCore.efi`: `2c59826d38e7730b49270eeb7e9db9f3e1fb1f5251c4cd9ee3672129338a1a78`
     - `EFI/OC/Drivers/OpenCanopy.efi`: `ac2ab7b704de6a10d115c149458fa5750e60de8de7c10893efd48bfb2a20fbb5`
5. **BẢO TOÀN 100% các cờ khởi động và thiết lập của Project 1401 (`NullMoth`) trên máy có GPU NVIDIA Ampere/Turing**:
   - Trong `boot-args`, khi tắt verbose chỉ được gỡ đúng token `-v`; **bắt buộc giữ nguyên** `nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0 gfxrst=4 -lilubetaall debug=0x100 keepsyms=1`.
   - Trong `Kernel -> Block`, mục `com.apple.iokit.IONDRVSupport` phải luôn `Enabled = True` với `MaxKernel = ""` (rỗng) để `NVRMFB` chiếm được Display Index 0 trên Tahoe 26.
   - Trong `Misc -> Security`, giữ `ExposeSensitiveData = 7` (để `1401.app` xác nhận được `boot-path` và `opencore-version`).
   - Trong `Misc -> Debug`, khi tắt chữ `[OC]` trên màn hình, đặt `Target = 66` (`2 [DataHub] + 64 [File]`, tắt bit `1 [Console]`) và `AppleDebug = False` để màn hình sạch 100% nhưng vẫn xuất `opencore-*.txt` cho trình kiểm tra của `1401.app`.
6. **LUÔN kiểm tra Kernel ABI trước khi cài `AirportItlwm_Tahoe.kext`**:
   - Chạy `kmutil libraries --bundle-path EFI/OC/Kexts/AirportItlwm_Tahoe.kext` trên bản macOS đích. Nếu lệnh trả về khác `0` (do Apple cập nhật XNU vtable mới), **dừng ghi EFI ngay** và chạy `bash patches/build-airportitlwm-tahoe.sh` để biên dịch lại kext từ nguồn C++ trước!
7. **LUÔN sao lưu EFI và chạy `plutil -lint` + `tools/ocvalidate/ocvalidate` trước khi unmount EFI**:
   - Không bao giờ đụng vào thư mục `EFI/Microsoft` (Windows Boot Manager) khi thao tác trên phân vùng ESP Dual-Boot!
   - Trước khi `diskutil unmount`, bắt buộc chạy `dot_clean -m` trên phân vùng FAT32 để xóa các file ẩn `._*` của macOS.
8. **Quy tắc viết Shell Script dưới `set -euo pipefail`**:
   - **Không dùng `grep -q` sau đường ống pipe lớn** (ví dụ `nm binary | grep -q ...`), vì `grep -q` đóng pipe sớm ngay dòng khớp đầu tiên làm lệnh trước nhận `SIGPIPE` (`exit 141`) và làm vỡ script dưới `pipefail`. Luôn dùng `grep "..." >/dev/null`!

---

## 2. Quy trình Khảo sát Máy Đích (Step 0 — Discovery)

Khi người dùng yêu cầu AI hỗ trợ trên một máy cụ thể, hãy chạy bước khảo sát chỉ-đọc (read-only) sau trước tiên:

```bash
# Kiểm tra CPU, số nhân vật lý, RAM, phiên bản macOS & trạng thái Sealed
sysctl -n machdep.cpu.brand_string hw.physicalcpu hw.logicalcpu hw.memsize
sw_vers
uname -r
diskutil list
diskutil info / | grep -E "Volume Name|APFS Volume Group|Sealed"
system_profiler SPDisplaysDataType SPNetworkDataType 2>/dev/null | head -n 80
```

### Cách AI tự động điều chỉnh `config.plist` nếu phần cứng người dùng khác máy mẫu (`Ryzen 5 7500F` - 6 nhân):

1. **Nếu CPU là AMD Ryzen nhưng số nhân vật lý (`hw.physicalcpu`) KHÁC `6`**:
   - Chuyển số nhân vật lý sang hệ Hex 2 chữ số (`6 -> 06`, `8 -> 08`, `12 -> 0C`, `16 -> 10`).
   - Dùng `python3` (`plistlib`) cập nhật byte thứ 2 trong trường `Replace` của 3 bản vá trong `Kernel -> Patch` có `Comment` bắt đầu bằng `algrey - Force cpuid_cores_per_package`:
     - `B8 06 00 00 00 00` → `B8 <HEX_CORES> 00 00 00 00`
     - `BA 06 00 00 00 00` → `BA <HEX_CORES> 00 00 00 00`
     - `BA 06 00 00 00 90` → `BA <HEX_CORES> 00 00 00 90`
2. **Nếu CPU là Intel (không phải AMD)**:
   - Không dùng bộ `Kernel -> Patch` AMD Vanilla này; báo rõ cho người dùng và tạo cấu hình Dortania Intel tương ứng cho dòng chip của họ, chỉ tái sử dụng phần cấu hình GPU RTX 3060 (`NullMoth`), `AirportItlwm_Tahoe.kext` (Intel AX210) và `OpenCanopy`.
3. **Nếu Mainboard khác dẫn đến sai cổng USB**:
   - Nhắc người dùng (hoặc tạm bật `XhciPortLimit` nếu trên bản hỗ trợ / tạo lại `UTBMap.kext` bằng `USBToolBox` trên Windows) để khớp đúng sơ đồ cổng USB thực tế.

---

## 3. Cây Quyết định Thực thi Tự động theo Yêu cầu Người dùng

### Kịch bản A: Chuẩn bị bộ EFI mới để chép ra USB cài đặt
1. Chạy `bash scripts/00-tao-smbios-rieng.sh` để tạo `SystemSerialNumber`, `MLB`, `SystemUUID`, `ROM` mới vào `EFI/OC/config.plist`.
2. Kiểm tra số nhân CPU đích và điều chỉnh `cpuid_cores_per_package` nếu khác 6 nhân.
3. Chạy `./tools/ocvalidate/ocvalidate EFI/OC/config.plist` và xác nhận kết quả `No issues found.`.
4. Hướng dẫn hoặc chép thư mục `EFI/` vào phân vùng EFI (FAT32) của USB.

### Kịch bản B: Nâng cấp máy đang chạy macOS Sequoia 15 lên macOS Tahoe 26
1. Chạy `sudo bash scripts/01-chuan-bi-len-tahoe.sh` để sao lưu EFI hiện tại và giới hạn các kext Sequoia cũ ở `Darwin 24.99.99`, đồng thời chép sẵn `AirportItlwm_Tahoe.kext` cho `Darwin 25.x`.
2. Sau khi người dùng nâng cấp xong lên macOS Tahoe 26:
   - Cài driver RTX 3060: `sudo bash scripts/02-cai-driver-rtx3060-sau-tahoe.sh <thư_mục_chứa_nullmoth>`
   - Kích hoạt Wi-Fi Native Apple + dọn OCLP cũ: `sudo bash scripts/03-kich-hoat-wifi-native-ax210.sh`
   - Bật giao diện OpenCanopy 4K + tắt log verbose: `sudo bash scripts/05-bat-giao-dien-opencanopy-ui.sh`

### Kịch bản C: Sửa lỗi mất Wi-Fi khi Restart từ Windows 11 sang macOS Tahoe (Intel AX210)
1. Xác minh card mạng là Intel Wi-Fi (`ioreg -l | grep -i 8086`).
2. Kiểm tra ký hiệu bản vá trong kext:
   ```bash
   nm EFI/OC/Kexts/AirportItlwm_Tahoe.kext/Contents/MacOS/AirportItlwm | grep "iwx_quiesce_warm_boot_hw" >/dev/null
   ```
3. Kiểm tra tương thích Kernel ABI với bản macOS đang chạy:
   ```bash
   kmutil libraries --bundle-path EFI/OC/Kexts/AirportItlwm_Tahoe.kext
   ```
   - Nếu báo lỗi thiếu symbol kernel (trên bản macOS Tahoe mới hơn `26.7.2`), chạy `bash patches/build-airportitlwm-tahoe.sh` để tự động clone `laobamac/itlwm`, áp dụng `patches/itlwm-tahoe-ax210-warm-reboot.patch`, và biên dịch lại bằng `xcodebuild`!
4. Cài đặt lên phân vùng EFI đang chạy:
   ```bash
   sudo bash scripts/04-cap-nhat-wifi-dualboot-ax210.sh
   ```
5. Khuyến nghị người dùng chạy thêm `scripts\windows\fix-wifi-dualboot-windows11.cmd` với quyền Admin bên Windows 11.

### Kịch bản D: Bật giao diện chọn Hệ điều hành (`OpenCanopy`) & Tắt chữ Log (`-v`)
1. Chạy `sudo bash scripts/05-bat-giao-dien-opencanopy-ui.sh`.
2. Lưu ý: Nếu máy người dùng có cài phần mềm giám sát bảo mật nội bộ (như `MacShield`), việc mount EFI và bỏ cờ `-v` khỏi `boot-args` sẽ được phần mềm ghi nhận đúng chức năng bảo mật — nhắc người dùng bấm **Tin cậy vĩnh viễn** cho `boot-args` mới sau khi khởi động lại (tuyệt đối không can thiệp trái phép vào cơ sở dữ liệu HMAC của phần mềm bảo mật).

---

## 4. Kiểm tra Nghiệm thu Sau Cùng (Post-Execution Verification)

Sau mọi thay đổi, AI Agent luôn chạy script kiểm tra sức khỏe để xác nhận hệ thống đạt chuẩn trước khi bàn giao:

```bash
bash scripts/08-kiem-tra-suc-khoe-hackintosh.sh
```
