# ==============================================================================
# SCRIPT TỰ ĐỘNG CẤU HÌNH CISCO VIA SSH
# ==============================================================================

# Thay đổi thông tin đăng nhập cho phù hợp
$deviceIP = "192.168.100.6"
$username = "admin"          
$password = "admin"

$scriptDir      = Split-Path -Parent $MyInvocation.MyCommand.Path
$syslogFilePath = Join-Path $scriptDir "cisco_ios_syslog_hostname.txt"

# Build commands
$commands = @()
$currentDate = Get-Date -Format "HH:mm:ss dd MMM yyyy"
$commands += "clock set $currentDate"
$commands += "conf t"
$commands += "clock timezone UTC +7 0"
$commands += "end"
$commands += "wri"


if (Test-Path $syslogFilePath) {
    Get-Content $syslogFilePath | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_) -and -not $_.Trim().StartsWith("!")
    } | ForEach-Object { $commands += $_.Trim() }
} else {
    Write-Error "Không tìm thấy file: $syslogFilePath"
    Exit
}

Import-Module Posh-SSH

$secPassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential  = New-Object System.Management.Automation.PSCredential($username, $secPassword)

Write-Host ">>> Đang kết nối SSH tới $deviceIP..." -ForegroundColor Cyan

# Thử các method auth khác nhau
try {
    $session = New-SSHSession -ComputerName $deviceIP -Credential $credential -AcceptKey -Force
} catch {
    Write-Error "Lỗi kết nối: $_"
    Exit
}

if ($session) {
    Write-Host ">>> Kết nối thành công!" -ForegroundColor Green

    $stream = New-SSHShellStream -SessionId $session.SessionId
    Start-Sleep -Seconds 2
    $stream.Read() | Out-Null

    foreach ($cmd in $commands) {
        Write-Host "  >> $cmd" -ForegroundColor Gray
        $stream.WriteLine($cmd)
        Start-Sleep -Milliseconds 500
        $out = $stream.Read()
        if ($out) { Write-Host $out -ForegroundColor DarkGray }
    }

    # Đóng stream đúng cách
    $stream.Close()                                    
    Remove-SSHSession -SessionId $session.SessionId
    Write-Host ">>> Hoàn thành!" -ForegroundColor Green
} else {
    Write-Error "Không thể kết nối tới $deviceIP"
}