@echo off
:: ============================================================================
:: TUY CHINH PHU TRO TREN WINDOWS 11 CHO DUAL-BOOT INTEL WI-FI 6E AX210
:: (Tat Windows Fast Startup / Hiberboot & D3 WoWLAN de giai phong PCIe sach se)
:: Cach chay tren Windows 11:
::   Chuot phai vao file nay -> chon "Run as administrator"
:: ============================================================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [LOI] Vui long chuot phai vao file va chon "Run as administrator"!
    pause
    exit /b 1
)

echo [1/2] Tat Windows Fast Startup (Hiberboot)...
powercfg /h off >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul

echo [2/2] Tat giu trang thai WoWLAN / Offload tren card Intel Wi-Fi AX210...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$adapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Intel.*(Wi-Fi|Wireless|AX210|AX200)' }; " ^
  "foreach ($a in $adapters) { " ^
  "  Write-Host ('  -> Dang cau hinh: ' + $a.Name + ' (' + $a.InterfaceDescription + ')'); " ^
  "  Disable-NetAdapterPowerManagement -Name $a.Name -WakeOnMagicPacket -WakeOnPattern -ArpOffload -NSOffload -DeviceSleepOnDisconnect -NoRestart -ErrorAction SilentlyContinue; " ^
  "  Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword '*WakeOnMagicPacket' -RegistryValue 0 -NoRestart -ErrorAction SilentlyContinue; " ^
  "  Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword '*WakeOnPattern' -RegistryValue 0 -NoRestart -ErrorAction SilentlyContinue; " ^
  "  Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword '*PMARPOffload' -RegistryValue 0 -NoRestart -ErrorAction SilentlyContinue; " ^
  "  Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword '*PMNSOffload' -RegistryValue 0 -NoRestart -ErrorAction SilentlyContinue; " ^
  "}"

echo.
echo [HOAN TAT] Da toi uu Windows 11 cho Dual-Boot cung macOS Tahoe!
pause
