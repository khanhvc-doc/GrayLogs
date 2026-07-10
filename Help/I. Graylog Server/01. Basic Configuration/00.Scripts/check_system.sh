#!/bin/bash

# ==============================================================================
# Script kiem tra suc khoe he thong Graylog va Dung luong phan vung
# ==============================================================================

# Dinh nghia mau sac cho de nhin (chi dung khi in ra man hinh)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Khong mau

# ---------------------------------------------------------
# CAU HINH LOG
# ---------------------------------------------------------
LOG_DIR="/backup/script/logs"
mkdir -p "$LOG_DIR"

# Ten file log = thoi gian bat dau kiem tra
LOG_FILE="$LOG_DIR/check_system_$(date +%Y%m%d_%H%M%S).log"

# Ham log: in ra man hinh (co mau) va ghi vao file log (bo ma mau, kem timestamp)
log() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    # In ra man hinh nguyen ban (giu mau)
    echo -e "$msg"

    # Ghi vao file log: loai bo ma mau ANSI truoc khi ghi
    local plain_msg
    plain_msg=$(echo -e "$msg" | sed -r 's/\x1B\[[0-9;]*[mK]//g')
    echo "[$ts] $plain_msg" >> "$LOG_FILE"
}

log "${BLUE}======================================================================${NC}"
log "${BLUE}        BAO CAO TRANG THAI HE THONG GRAYLOG & LUU TRU ${NC}"
log "${BLUE}======================================================================${NC}"
log "Thoi gian kiem tra: $(date '+%Y-%m-%d %H:%M:%S')"
log ""

# ---------------------------------------------------------
# 1. KIEM TRA SUC KHOE DOCKER VA CAC CONTAINER
# ---------------------------------------------------------
log "${YELLOW}1. KIEM TRA TRANG THAI DICH VU & CONTAINER${NC}"

# Kiem tra Docker Engine
if systemctl is-active --quiet docker; then
    log "  [+] Dich vu Docker: ${GREEN}DANG CHAY (Running)${NC}"
else
    log "  [+] Dich vu Docker: ${RED}DA DUNG (Stopped/Failed)${NC} - Hay kiem tra lai Docker Engine!"
fi

# Kiem tra cac Container lien quan den he thong Graylog
log ""
log "  [+] Danh sach trang thai Container (Graylog, OpenSearch, MongoDB):"
log "  ----------------------------------------------------------------"

# Loc ra cac container co ten chua graylog, opensearch, mongo
CONTAINERS=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -iE "graylog|opensearch|mongo|elastic|NAME")

if [ -z "$CONTAINERS" ]; then
    log "  ${RED}Khong tim thay container nao lien quan den Graylog dang chay!${NC}"
else
    # In ra danh sach va boi mau trang thai, dong thoi ghi log
    echo "$CONTAINERS" | while read -r line; do
        if echo "$line" | grep -qi "Up"; then
            log "      ${GREEN}$line${NC}"
        elif echo "$line" | grep -qi "Exited"; then
            log "      ${RED}$line${NC}"
        else
            log "      $line"
        fi
    done
fi
log ""

# ---------------------------------------------------------
# 2. KIEM TRA DUNG LUONG O CUNG (Disk 1, 2, 3)
# ---------------------------------------------------------
log "${YELLOW}2. KIEM TRA DUNG LUONG LUU TRU${NC}"

# Ham kiem tra dung luong o cung
check_disk() {
    local label=$1
    local path=$2
    local expected_size=$3

    if [ -d "$path" ]; then
        # Lay thong so tu lenh df -h
        local total avail used pcent
        total=$(df -h "$path" | tail -n 1 | awk '{print $2}')
        used=$(df -h "$path" | tail -n 1 | awk '{print $3}')
        avail=$(df -h "$path" | tail -n 1 | awk '{print $4}')
        pcent=$(df -h "$path" | tail -n 1 | awk '{print $5}' | tr -d '%')

        log "  [+] ${label} (Mac dinh: ~${expected_size})"
        log "      - Duong dan : $path"
        log "      - Tong cong : $total"
        log "      - Da su dung: $used"
        log "      - Con trong : $avail"

        # Canh bao neu dung luong vuot qua 85%
        if [ "$pcent" -ge 85 ]; then
            log "      - Muc dung  : ${RED}$pcent% (CANH BAO: Sap day!)${NC}"
        else
            log "      - Muc dung  : ${GREEN}$pcent% (Binh thuong)${NC}"
        fi
    else
        log "  [+] ${label}"
        log "      ${RED}Khong tim thay thu muc/phan vung mounted tai: $path${NC}"
    fi
    log ""
}

# Disk 1: Phan vung he dieu hanh (/)
check_disk "Disk 1 - He dieu hanh & Config" "/" "100GB"

# Disk 2: Phan vung du lieu (/data)
check_disk "Disk 2 - Du lieu Log (OpenSearch, MongoDB, Graylog)" "/data" "500GB"

# Disk 3: Phan vung Backup (/backup)
check_disk "Disk 3 - Luu tru Backup" "/backup" "50GB"

log "${BLUE}======================================================================${NC}"
log "${GREEN}Hoan tat kiem tra!${NC}"
log "Chi tiet log duoc luu tai: $LOG_FILE"