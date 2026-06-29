# ==============================================================================
# SCRIPT CẤU HÌNH LOGGING ORIGIN-ID VIA SSH
# Đăng nhập → Lấy hostname → Thay logging origin-id → Lưu → Thoát
# ==============================================================================
$deviceIP   = "192.168.100.8"
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
$stream.WriteLine("show run | include hostname")
Start-Sleep -Seconds 5
$rawResult = $stream.Read()

Write-Host "--- Raw output ---" -ForegroundColor DarkGray
Write-Host $rawResult -ForegroundColor DarkGray