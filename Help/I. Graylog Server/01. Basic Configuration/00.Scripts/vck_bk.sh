#!/bin/bash

# Thêm dong nay de script dung lai lap tuc neu mot trong cac buoc con bi loi
set -e

echo "=== Bat dau qua trinh xu ly ==="

SOURCE_DIR="/backup/graylog"

# Xoa cac file .gz cu (neu co)
echo "1. Dang xoa cac file .gz cu..."
if [ -d "$SOURCE_DIR" ]; then
    # Them -f de neu khong co file .gz nao thi rm khong bao loi thua
    rm -f "$SOURCE_DIR"/*.gz
else
    echo "Thu muc $SOURCE_DIR khong ton tai!"
    exit 1
fi

# Chay script backup
echo "2. Dang tien hanh backup Graylog..."
/backup/script/backup_graylog.sh

# Chay script copy sang FTP
echo "3. Dang copy file backup len FTP..."
/backup/script/copy_gz_to_ftp.sh

echo "=== TAT CA DA HOAN THANH VAO LUC $(date) ==="