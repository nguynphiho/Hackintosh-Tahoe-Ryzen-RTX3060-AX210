# Instructions for AI Agents (`AGENTS.md`)

Khi hỗ trợ người dùng trên repository Hackintosh macOS Tahoe 26 này, **BẮT BUỘC đọc toàn bộ tệp [`AI_AGENT_GUIDE.md`](./AI_AGENT_GUIDE.md) trước khi thực thi bất kỳ lệnh nào**.

## Tóm tắt nhanh các quy tắc bắt buộc:
1. **Bảo vệ Apple ID / SMBIOS**: Không bao giờ commit `SystemSerialNumber`, `MLB`, `SystemUUID`, `ROM` thật lên Git công khai; luôn chạy `bash scripts/00-tao-smbios-rieng.sh` khi triển khai lên máy mới.
2. **Giữ nguyên `Sealed: Yes`**: Không bao giờ chạy OCLP Root Patch trên macOS Tahoe 26 khi dùng driver RTX 3060 (`Project 1401 / NullMoth`). Dùng `AirportItlwm_Tahoe.kext` từ `EFI/OC/Kexts` để có Wi-Fi Native.
3. **Đồng bộ OpenCore Binary & Kiểm định**: Không trộn file `.efi` khác bản build; luôn kiểm tra `kmutil libraries` cho kext nhân và chạy `plutil -lint` + `./tools/ocvalidate/ocvalidate` trước khi unmount phân vùng EFI (không bao giờ xóa `EFI/Microsoft`).
4. **Chi tiết đầy đủ cho từng kịch bản**: Xem [`AI_AGENT_GUIDE.md`](./AI_AGENT_GUIDE.md) và [`README.md`](./README.md).
