# Bản vá C++ `AirportItlwm_Tahoe.kext` — Khắc phục mất Wi-Fi khi Restart ấm từ Windows 11 sang macOS Tahoe 26

## 1. Triệu chứng lỗi gốc (Dual-Boot Warm Reboot Bug)
Trên các máy Dual-Boot **Windows 11 + macOS Tahoe 26** dùng card **Intel Wi-Fi 6E AX210 (`pci8086,2725`)**:
- Khi khởi động nguội (Cold Boot) vào macOS: Wi-Fi Native nhận ngay.
- Nhưng khi vào **Windows 11**, sau đó nhấn **Start → Restart** để chuyển thẳng sang **macOS Tahoe**:
  - Windows driver `Netwtw10.sys` để lại card AX210 ở trạng thái nguồn `D0A` với các thanh ghi ngắt `MSI-X`, `FH_TSSR` DMA TX/RX và ngữ cảnh firmware WRT/alive còn đang hoạt động dở dang (do bo mạch chủ không ngắt nguồn `3.3Vaux` PCIe khi Warm Reboot).
  - Hàm `iwx_preinit()` gốc chỉ gọi `iwx_start_hw()` 1 lần duy nhất mà không dọn trạng thái DMA/MSI-X tồn đọng và không thực hiện PCIe Function-Level Reset (`FLR`), dẫn đến timeout nạp firmware ngay lần boot đầu tiên (phải Restart thêm lần thứ 2 mới có Wi-Fi).

## 2. Cơ chế khắc phục trong `itlwm-tahoe-ax210-warm-reboot.patch`
Bản vá sửa trực tiếp tầng HAL `hal_iwx` (`itlwm/hal_iwx/ItlIwx.hpp` & `itlwm/hal_iwx/ItlIwx.cpp`) trên nền `laobamac/itlwm` (`v2.4.0-alpha`, commit `7204c69`):
1. **`iwx_quiesce_warm_boot_hw()`**: Trước khi khởi tạo phần cứng, cưỡng bức vô hiệu hóa toàn bộ ngắt `CSR_INT_MASK` / `MSIX_FH_INT_MASK` / `MSIX_HW_INT_MASK`, tắt các kênh DMA TX/RX của Windows để lại, xóa cờ `CSR_RESET_REG_FLAG_MASTER_DISABLED` / `STOP_MASTER` và giải phóng khóa MAC access.
2. **`iwx_pcie_flr_reset()`**: Quét PCI Express Capability (`0x10`), kiểm tra cờ `PCI_EXP_DEVCAP_FLR` (`bit 28`), tắt tạm Bus Master, kích hoạt **PCIe Function-Level Reset (`PCI_EXP_DEVCTL_BCR_FLR`, `bit 15`)**, chờ chuẩn `100 ms` theo đặc tả PCIe và khôi phục `PCI_COMMAND_MASTER | PCI_COMMAND_MEMORY` cùng thanh ghi `BAR0`.
3. **Cơ chế tự phục hồi 4 vòng lặp trong `iwx_preinit()`**: Nếu lần nạp firmware đầu tiên sau khi sang từ Windows gặp trạng thái treo của chip AX210, driver tự động thực thi chuỗi `quiesce -> PCIe FLR -> start_hw -> load_ucode_wait_alive` tối đa 4 lần ngay trong quá trình boot đầu tiên.

## 3. Cách tự biên dịch lại từ mã nguồn
Bản kext đã biên dịch sẵn (đã strip sạch đường dẫn debug máy build) nằm tại `EFI/OC/Kexts/AirportItlwm_Tahoe.kext` (`SHA-256: 340125a5e427c783c8365137e6f63da2b866614548bd711dd0368e642f9b7ef2`).
Nếu muốn tự kiểm tra mã nguồn và biên dịch lại bằng Xcode:

```bash
bash patches/build-airportitlwm-tahoe.sh
```
