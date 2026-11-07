@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo ======================================================================
echo   BUOC 01 (WINDOWS): TAI BO CAI MACOS TAHOE 26 RECOVERY CHINH HANG APPLE
echo ======================================================================
echo.

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_DIR=%%~fI"
set "MACREC_PY=%REPO_DIR%\tools\macrecovery\macrecovery.py"

if not exist "%MACREC_PY%" (
    echo [LOI] Khong tim thay file: %MACREC_PY%
    pause
    exit /b 1
)

:: Kiem tra Python 3 that (tranh stub cua Microsoft Store)
set "PY_CMD="
py -3 --version >nul 2>&1
if !errorlevel! equ 0 (
    set "PY_CMD=py -3"
) else (
    python --version >nul 2>&1
    if !errorlevel! equ 0 (
        set "PY_CMD=python"
    )
)

if "%PY_CMD%"=="" (
    echo [CHUA CAI PYTHON 3 TREN WINDOWS]
    echo De tai truc tiep macOS Tahoe Recovery tu may chu Apple bang macrecovery,
    echo ban can cai Python 3 tren Windows ^(chi mat 30 giay^):
    echo.
    echo   Cach 1 ^(Nhanh nhat - mo PowerShell/CMD go lenh^):
    echo     winget install -e --id Python.Python.3.12
    echo.
    echo   Cach 2 ^(Khong can Python - dung phan mem 1401 Windows cua NullMoth^):
    echo     Tai tai: https://github.com/nullmoth/1401/releases/latest
    echo     ^(File: 1401-Windows-2.7.2.zip - chay 1401.exe de tao USB macOS Tahoe,
    echo      sau do chay tiep script 02-chuan-bi-efi-cai-moi-windows.cmd de ghi de
    echo      bo EFI da toi uu Wi-Fi Native AX210 Dual-Boot + OpenCanopy 4K len USB!^)
    echo.
    pause
    exit /b 1
)

echo Da tim thay Python: %PY_CMD%
echo.
echo Nhap ky tu o USB FAT32 ^(vi du: E^) de tai thang vao USB,
echo hoac nhan [Enter] de tai vao thu muc repo ^(%REPO_DIR%\com.apple.recovery.boot^):
set /p "USB_DRV=> Ky tu o USB (bo trong neu luu tai cho): "

if "%USB_DRV%"=="" (
    set "OUT_DIR=%REPO_DIR%\com.apple.recovery.boot"
) else (
    set "USB_LETTER=%USB_DRV:~0,1%"
    if not exist "!USB_LETTER!:\" (
        echo [LOI] Khong tim thay o dia !USB_LETTER!:\ !
        pause
        exit /b 1
    )
    set "OUT_DIR=!USB_LETTER!:\com.apple.recovery.boot"
)

echo.
echo Dang tai macOS Tahoe 26 Recovery ^(BaseSystem.dmg ~ 800 MB^) tu Apple...
echo Thu muc luu: "%OUT_DIR%"
echo Vui long cho den khi tai xong 100%%...
echo.

pushd "%REPO_DIR%\tools\macrecovery"
%PY_CMD% macrecovery.py -b Mac-CFF7D910A743CAAF -m 00000000000000000 -os latest -o "%OUT_DIR%" download
set "DL_RC=%errorlevel%"
popd

if not "%DL_RC%"=="0" (
    echo.
    echo [LOI] Qua trinh tai bi gian doan ^(ma loi %DL_RC%^). Vui long kiem tra mang va chay lai!
    pause
    exit /b %DL_RC%
)

echo.
echo ======================================================================
echo [HOAN TAT] Da tai xong bo cai macOS Tahoe 26 Recovery!
echo   Vi tri: %OUT_DIR%
echo   Tiep theo: Chay 02-chuan-bi-efi-cai-moi-windows.cmd de tao SMBIOS rieng
echo   va chep bo EFI Stage-1 ^(chong den man hinh khi cai moi^) ra USB!
echo ======================================================================
pause
