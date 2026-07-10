#!/bin/bash

# ==========================================
# CẤU HÌNH FTP SERVER
# ==========================================
FTP_SERVER="192.168.99.22"
FTP_USER="bkconfig"
FTP_PASS="bkconfig1357"
FTP_DIR="/01.devices/Graylog/" # Thư mục đích trên FTP (bắt buộc có dấu / ở cuối)

# Thu muc chua cac file backup (.tar.gz...) can upload
SOURCE_DIR="/backup/graylog"

# Thu muc chua script va file danh sach
SCRIPT_DIR="/backup/script"
LIST_FILE="$SCRIPT_DIR/bk_list_file.txt"

# Thu muc luu file log
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# Ten file log = thoi gian bat dau chay backup
LOG_FILE="$LOG_DIR/backup_$(date +%Y%m%d_%H%M%S).log"

# Ham ghi log: vua in ra man hinh, vua ghi vao file log kem timestamp
log() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$msg"
    echo "[$ts] $msg" >> "$LOG_FILE"
}

# ==========================================
# BAT DAU THUC THI
# ==========================================
if [ ! -f "$LIST_FILE" ]; then
    log "Loi: Khong tim thay file danh sach '$LIST_FILE'"
    exit 1
fi

log "Bat dau tien trinh upload len FTP..."
log "Nguon: $SOURCE_DIR -> Dich: ftp://$FTP_SERVER$FTP_DIR"

TOTAL=0
SUCCESS=0
FAILED=0

while IFS= read -r raw_filename || [ -n "$raw_filename" ]; do

    # Loai bo ky tu an \r (neu file text copy tu Windows sang) va khoang trang thua
    filename=$(echo "$raw_filename" | tr -d '\r' | xargs)
    if [ -z "$filename" ]; then
        continue
    fi

    TOTAL=$((TOTAL + 1))

    # File backup nam trong SOURCE_DIR
    FILE_PATH="$SOURCE_DIR/$filename"
    if [ ! -f "$FILE_PATH" ]; then
        log "Canh bao: File '$FILE_PATH' khong ton tai tren he thong. Bo qua!"
        FAILED=$((FAILED + 1))
        continue
    fi

    log "Dang upload: $filename -> ftp://$FTP_SERVER$FTP_DIR$filename"

    curl -s -T "$FILE_PATH" "ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER$FTP_DIR"

    if [ $? -eq 0 ]; then
        log "Upload thanh cong: $filename -> $FTP_DIR$filename"
        SUCCESS=$((SUCCESS + 1))
    else
        log "Loi khi upload: $filename"
        FAILED=$((FAILED + 1))
    fi

done < "$LIST_FILE"

log "Hoan thanh tien trinh! Tong: $TOTAL | Thanh cong: $SUCCESS | That bai: $FAILED"
log "Chi tiet log duoc luu tai: $LOG_FILE"