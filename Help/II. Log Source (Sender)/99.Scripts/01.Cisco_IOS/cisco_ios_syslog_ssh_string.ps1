# ==============================================================================
# SCRIPT CẤU HÌNH LOGGING ORIGIN-ID VIA SSH
# Đăng nhập → Lấy hostname → Thay logging origin-id → Lưu → Thoát
# ==============================================================================
$deviceIP   = "192.168.100.6"
$username   = "admin"
$password   = "admin"

Import-Module Posh-SSH

$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential  = New-Object System.Management.Automation.PSCredential($username, $secPassword)

Write-Host ">>> Đang kết nối SSH tới $deviceIP..." -ForegroundColor Cyan

try {
    $session = New-SSHSession -ComputerName $deviceIP -Credential $credential -AcceptKey -Force
} catch {
    Write-Error "Lỗi kết nối: $_"
    Exit
}

if (-not $session) {
    Write-Error "Không thể kết nối tới $deviceIP"
    Exit
}

Write-Host ">>> Kết nối thành công!" -ForegroundColor Green

# ============================================================
# BƯỚC 1: Khởi tạo stream — chờ prompt
# ============================================================
$stream = New-SSHShellStream -SessionId $session.SessionId

$banner = ""
$timeout = 0
while ($banner -notmatch '[#>]' -and $timeout -lt 5000) {
    Start-Sleep -Milliseconds 500
    $banner += $stream.Read()
    $timeout += 500
}
Write-Host "--- Prompt sẵn sàng ---" -ForegroundColor DarkGray

# ============================================================
# BƯỚC 2: Lấy hostname
# ============================================================
$stream.WriteLine("sh run | inc hostname")
Start-Sleep -Seconds 5                     # nhiều khi không lấy được hostname do thơi gian ít quá
$rawResult = $stream.Read()

Write-Host "--- Raw output ---" -ForegroundColor DarkGray
Write-Host $rawResult -ForegroundColor DarkGray

$ciscoHostname = ($rawResult -split "`n" |
    Where-Object { $_ -notmatch "\|" } |
    Where-Object { $_ -notmatch "#" } |
    Where-Object { $_.Trim() -match "hostname\s+\S+" } |
    Select-Object -First 1) -replace ".*hostname\s+", "" `
                            -replace "\r", "" |
    ForEach-Object { $_.Trim() }

if ([string]::IsNullOrEmpty($ciscoHostname)) {
    Write-Warning "Không lấy được hostname, fallback về IP"
    $ciscoHostname = $deviceIP
}

Write-Host ">>> Hostname: $ciscoHostname" -ForegroundColor Yellow

# ============================================================
# BƯỚC 3: Thay logging origin-id và lưu
# ============================================================
$newOriginId = "logging origin-id string `"${ciscoHostname}_IP_${deviceIP}`""

Write-Host ">>> Đang cấu hình: $newOriginId" -ForegroundColor Cyan

$configCmds = @(
    "conf t",
    "no logging origin-id",        # xóa dòng cũ bất kể là gì
    $newOriginId,                  # thêm dòng mới
    "end",
    "wri"
    "exit"
)

foreach ($cmd in $configCmds) {
    Write-Host "  >> $cmd" -ForegroundColor Gray
    $stream.WriteLine($cmd)
    Start-Sleep -Milliseconds 500
    $out = $stream.Read()
    if ($out) { Write-Host $out -ForegroundColor DarkGray }
}

# ============================================================
# BƯỚC 4: Cleanup
# ============================================================
$stream.Close()
Remove-SSHSession -SessionId $session.SessionId

Write-Host ">>> Hoàn thành! Đã cấu hình: $newOriginId" -ForegroundColor Green