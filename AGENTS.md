# Instructions for AI Agents (`AGENTS.md`)

Khi hỗ trợ người dùng trên repository Hackintosh macOS Tahoe 26 này, **BẮT BUỘC đọc toàn bộ tệp [`AI_AGENT_GUIDE.md`](./AI_AGENT_GUIDE.md) trước khi thực thi bất kỳ lệnh nào**.

## Tóm tắt nhanh các quy tắc bắt buộc:
1. **Kiến trúc Config 2 Giai đoạn**: Khi tạo USB cài mới từ Windows/macOS (chưa cài driver NullMoth), **bắt buộc dùng Stage 1** (`EFI/OC/config-stage1-cai-moi.plist` hoặc chạy `scripts\windows\02-chuan-bi-efi-cai-moi-windows.cmd` / `bash scripts/00-tao-smbios-rieng.sh --stage1`) để mở `IONDRVSupport`. Chỉ bật **Stage 2** (`IONDRVSupport` blocked + full flags chống màn hình đen trỏ chuột + BIOS `Resizable BAR = Enabled`) sau khi đã cài gói driver RTX 3060 (`NullMoth`).
2. **Bảo vệ Apple ID / SMBIOS**: Không bao giờ commit `SystemSerialNumber`, `MLB`, `SystemUUID`, `ROM` thật lên Git công khai; luôn sinh SMBIOS riêng khi triển khai lên máy mới.
3. **Giữ nguyên `Sealed: Yes`**: Không bao giờ chạy OCLP Root Patch trên macOS Tahoe 26 khi dùng driver RTX 3060 (`Project 1401 / NullMoth`). Dùng `AirportItlwm_Tahoe.kext` từ `EFI/OC/Kexts` để có Wi-Fi Native.
4. **Đồng bộ OpenCore Binary & Kiểm định**: Không trộn file `.efi` khác bản build; luôn kiểm tra `kmutil libraries` cho kext nhân và chạy `plutil -lint` + `./tools/ocvalidate/ocvalidate` trước khi unmount phân vùng EFI (không bao giờ xóa `EFI/Microsoft`).
5. **Chi tiết đầy đủ cho từng kịch bản**: Xem [`AI_AGENT_GUIDE.md`](./AI_AGENT_GUIDE.md) và [`README.md`](./README.md).
