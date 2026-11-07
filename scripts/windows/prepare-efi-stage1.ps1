param(
    [Parameter(Mandatory = $true)]
    [string]$RepoDir
)

$ErrorActionPreference = "Stop"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  BUOC 02 (WINDOWS): TAO SMBIOS RIENG + CAU HINH EFI CAI MOI (STAGE 1)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

$Stage1Cfg  = Join-Path $RepoDir "EFI\OC\config-stage1-cai-moi.plist"
$TargetCfg  = Join-Path $RepoDir "EFI\OC\config.plist"
$MacSerial  = Join-Path $RepoDir "tools\macserial\macserial.exe"
$OcValidate = Join-Path $RepoDir "tools\ocvalidate\ocvalidate.exe"

foreach ($p in @($Stage1Cfg, $MacSerial, $OcValidate)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host "[LOI] Khong tim thay file bat buoc: $p" -ForegroundColor Red
        exit 1
    }
}

# 1. Sinh Serial + MLB MacPro7,1 bang macserial.exe chinh hang OpenCore 1.0.9
Write-Host "[1/5] Sinh ma dinh danh SMBIOS MacPro7,1 rieng cho may cua ban..." -ForegroundColor Yellow
$rawSerial = & $MacSerial -m MacPro7,1 -n 1 | Select-Object -First 1
if (-not $rawSerial -or ($rawSerial -notmatch "\|")) {
    Write-Host "[LOI] Khong the sinh Serial tu macserial.exe!" -ForegroundColor Red
    exit 1
}
$parts  = $rawSerial -split "\|"
$serial = $parts[0].Trim()
$mlb    = $parts[1].Trim()
$uuid   = [guid]::NewGuid().ToString().ToUpper()

# Lay MAC that cua cong Ethernet vat ly (chuan Apple iMessage), neu khong co thi sinh MAC Locally Administered hop le
$romBytes = $null
try {
    $nic = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
           Where-Object { $_.MacAddress -and $_.InterfaceDescription -notmatch "Wi-Fi|Wireless|Bluetooth|Virtual" } |
           Select-Object -First 1
    if ($nic -and $nic.MacAddress) {
        $hexClean = ($nic.MacAddress -replace "[^0-9A-Fa-f]", "")
        if ($hexClean.Length -eq 12) {
            $romBytes = New-Object byte[] 6
            for ($i = 0; $i -lt 6; $i++) {
                $romBytes[$i] = [Convert]::ToByte($hexClean.Substring($i * 2, 2), 16)
            }
        }
    }
} catch {}

if (-not $romBytes) {
    $romBytes = New-Object byte[] 6
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($romBytes)
    $romBytes[0] = ($romBytes[0] -band 0xFE) -bor 0x02
}
$romHex = ($romBytes | ForEach-Object { $_.ToString("X2") }) -join ""
$romB64 = [Convert]::ToBase64String($romBytes)

# 2. Phat hien CPU & So nhan vat ly AMD Ryzen tren may Windows
Write-Host "[2/5] Kiem tra CPU va so nhan vat ly..." -ForegroundColor Yellow
$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$cpuName = ($cpu.Name).Trim()
$detectedCores = [int]$cpu.NumberOfCores
Write-Host "      CPU phat hien : $cpuName ($detectedCores nhan vat ly)"

$targetCores = 6
if ($cpuName -match "AMD|Ryzen") {
    $ans = Read-Host "      Nhan [Enter] de dung $detectedCores nhan cho CPU nay, hoac nhap so nhan khac (6/8/12/16) neu tao USB cho may AMD khac"
    if ([string]::IsNullOrWhiteSpace($ans)) {
        $targetCores = $detectedCores
    } else {
        $targetCores = [int]$ans.Trim()
    }
} else {
    Write-Host "      [LUU Y] May Windows hien tai khong phai CPU AMD ($cpuName)." -ForegroundColor Magenta
    $ans = Read-Host "      Neu ban dang tao USB cai cho may PC AMD Ryzen khac, nhap so nhan vat ly cua may AMD do (mac dinh 6)"
    if (-not [string]::IsNullOrWhiteSpace($ans)) {
        $targetCores = [int]$ans.Trim()
    }
}

if ($targetCores -lt 2 -or $targetCores -gt 64) {
    Write-Host "[LOI] So nhan CPU khong hop le: $targetCores" -ForegroundColor Red
    exit 1
}

# 3. Doc mau Stage-1 va cap nhat SMBIOS + CPU Core Count Patch (4 ban va 10.13 -> Tahoe 26)
Write-Host "[3/5] Ghi cau hinh Stage-1 (Cai moi tu USB - khong bi den man hinh) vao EFI\OC\config.plist..." -ForegroundColor Yellow
$xmlText = [System.IO.File]::ReadAllText($Stage1Cfg, [System.Text.Encoding]::UTF8)

function Replace-PlistKeyString([string]$content, [string]$keyName, [string]$newValue) {
    $rx = [regex]::new("(<key>$([regex]::Escape($keyName))</key>\s*<string>)([^<]*)(</string>)")
    return $rx.Replace($content, "`${1}$newValue`${3}", 1)
}

function Replace-PlistKeyData([string]$content, [string]$keyName, [string]$newBase64) {
    $rx = [regex]::new("(<key>$([regex]::Escape($keyName))</key>\s*<data>\s*)([A-Za-z0-9+/=]+)(\s*</data>)")
    return $rx.Replace($content, "`${1}$newBase64`${3}", 1)
}

$xmlText = Replace-PlistKeyString $xmlText "MLB" $mlb
$xmlText = Replace-PlistKeyString $xmlText "SystemSerialNumber" $serial
$xmlText = Replace-PlistKeyString $xmlText "SystemUUID" $uuid
$xmlText = Replace-PlistKeyData   $xmlText "ROM" $romB64

# Tinh Base64 cho 4 ban va algrey | Force cpuid_cores_per_package voi $targetCores nhan
$c = [byte]$targetCores
$b64_1013 = [Convert]::ToBase64String([byte[]]@(0xB8, $c, 0x00, 0x00, 0x00, 0x00))
$b64_1015 = [Convert]::ToBase64String([byte[]]@(0xBA, $c, 0x00, 0x00, 0x00, 0x00))
$b64_1200 = [Convert]::ToBase64String([byte[]]@(0xBA, $c, 0x00, 0x00, 0x00, 0x90))
$b64_1303 = [Convert]::ToBase64String([byte[]]@(0xBA, $c, 0x00, 0x00, 0x00))

$patchMap = @{
    "10.13-10.14" = $b64_1013
    "10.15-11.0"  = $b64_1015
    "12.0-13.2"   = $b64_1200
    "13.3+"       = $b64_1303
}

foreach ($ver in $patchMap.Keys) {
    $newB64 = $patchMap[$ver]
    $rxPatch = [regex]::new("(<string>algrey \| Force cpuid_cores_per_package to constant \(user-specified\) \| $([regex]::Escape($ver))</string>[\s\S]*?<key>Replace</key>\s*<data>\s*)([A-Za-z0-9+/=]+)(\s*</data>)")
    $xmlText = $rxPatch.Replace($xmlText, "`${1}$newB64`${3}", 1)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($TargetCfg, $xmlText, $utf8NoBom)

# 4. Kiem dinh bang ocvalidate.exe
Write-Host "[4/5] Kiem dinh cau hinh bang ocvalidate.exe (OpenCore 1.0.9)..." -ForegroundColor Yellow
$ocOut = & $OcValidate $TargetCfg 2>&1 | Out-String
if ($ocOut -notmatch "No issues found\.") {
    Write-Host "[LOI] ocvalidate phat hien van de:" -ForegroundColor Red
    Write-Host $ocOut
    exit 1
}
Write-Host "      [OK] ocvalidate: No issues found!" -ForegroundColor Green

Write-Host ""
Write-Host "  + SystemProductName  : MacPro7,1"
Write-Host "  + SystemSerialNumber : $serial"
Write-Host "  + MLB (Board Serial) : $mlb"
Write-Host "  + SystemUUID         : $uuid"
Write-Host "  + ROM (MAC Hex)      : $romHex"
Write-Host "  + AMD CPU Cores      : $targetCores nhan vat ly"
Write-Host "  + Che do Config      : STAGE 1 (Mo IONDRVSupport + -nvoff + -v de cai moi tu USB an toan 100%)"
Write-Host ""

# 5. Tuy chon chep thang ra USB FAT32
Write-Host "[5/5] Chep bo EFI + Bo cong cu Hau cai dat sang USB FAT32..." -ForegroundColor Yellow
$usbAns = Read-Host "      Nhap ky tu o USB FAT32 (vi du: E) de chep tu dong, hoac nhan [Enter] neu ban tu chep tay"
if (-not [string]::IsNullOrWhiteSpace($usbAns)) {
    $driveLetter = $usbAns.Trim().Substring(0, 1).ToUpper()
    $usbRoot = "${driveLetter}:\"
    if (-not (Test-Path -LiteralPath $usbRoot)) {
        Write-Host "[LOI] Khong tim thay o dia $usbRoot !" -ForegroundColor Red
        exit 1
    }

    $vol = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
    if ($vol -and $vol.FileSystem -ne "FAT32") {
        Write-Host "[CANH BAO] O $usbRoot dang co dinh dang $($vol.FileSystem) (khong phai FAT32)!" -ForegroundColor Red
        Write-Host "           Hay format USB sang FAT32 + GPT bang Rufus truoc khi boot UEFI!" -ForegroundColor Red
    }

    Write-Host "      Dang chep EFI\ sang ${usbRoot}EFI ..."
    if (Test-Path -LiteralPath "${usbRoot}EFI\OC") {
        Remove-Item -LiteralPath "${usbRoot}EFI\OC" -Recurse -Force
    }
    if (Test-Path -LiteralPath "${usbRoot}EFI\Boot") {
        Remove-Item -LiteralPath "${usbRoot}EFI\Boot" -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path "${usbRoot}EFI" | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoDir "EFI\Boot") -Destination "${usbRoot}EFI\Boot" -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $RepoDir "EFI\OC")   -Destination "${usbRoot}EFI\OC"   -Recurse -Force

    # Neu da tai com.apple.recovery.boot trong thu muc repo thi chep luon sang USB
    $localRec = Join-Path $RepoDir "com.apple.recovery.boot"
    if ((Test-Path -LiteralPath $localRec) -and (-not (Test-Path -LiteralPath "${usbRoot}com.apple.recovery.boot"))) {
        Write-Host "      Dang chep com.apple.recovery.boot\ (macOS Tahoe Recovery) sang $usbRoot ..."
        Copy-Item -LiteralPath $localRec -Destination "${usbRoot}com.apple.recovery.boot" -Recurse -Force
    }

    # Chep luon bo repo vao thu muc HACKINTOSH-TOOLS tren USB de vao macOS chay script buoc 2, 3, 5, 10 ngay!
    $toolsDest = "${usbRoot}HACKINTOSH-TOOLS"
    Write-Host "      Dang chep bo scripts hau cai dat vao $toolsDest (de sang macOS dung ngay)..."
    New-Item -ItemType Directory -Force -Path $toolsDest | Out-Null
    foreach ($item in @("EFI", "patches", "scripts", "tools", "README.md", "AI_AGENT_GUIDE.md", "AGENTS.md", "CLAUDE.md")) {
        $srcItem = Join-Path $RepoDir $item
        if (Test-Path -LiteralPath $srcItem) {
            Copy-Item -LiteralPath $srcItem -Destination (Join-Path $toolsDest $item) -Recurse -Force
        }
    }

    Write-Host "      [OK] Da chuan bi xong USB tai $usbRoot !" -ForegroundColor Green
    Write-Host "      MEO: Neu ban da tai 1401-Mac-2.7.2.dmg va nullmoth-nvidia-2.7.2.tar.gz tren Windows," -ForegroundColor Cyan
    Write-Host "           hay chep 2 file do vao thu muc ${toolsDest}\ tren USB luon de cai Offline cuc nhanh!" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "[HOAN TAT] Bo EFI Stage-1 da san sang de boot USB cai moi macOS Tahoe 26!" -ForegroundColor Green
Write-Host "Sau khi cai xong macOS Tahoe, mo Terminal chay scripts/02-cai-driver-rtx3060-sau-tahoe.sh" -ForegroundColor Green
Write-Host "de tu dong cai driver RTX 3060 Metal 3 va nang EFI len Stage-2 hoan chinh!" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
