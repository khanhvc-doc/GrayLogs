# CẤU HÌNH

## 1. Trên Graylog

- Cấu hình Syslog lắng nghe tất cả các thiết bị gửi về, lắng nghe trên **port 1514** (vì trong trong docker cấu hình 1514)

![alt text](image.png)

- Kết quả

![alt text](image-1.png)

## 2. Backup cấu hình Graylog

### 2.1 Mục tiêu:

- Cấu hình triển khai
- Database Graylog (MongoDB)
- Dữ liệu log/index (OpenSearch)
- Journal Graylog
- Backup archive vào đưa vào **/backup/graylog**
- Lập lịch backup hàng ngày

### 2.2 Thực hiện:

#### - Tạo file `/usr/local/bin/backup_graylog.sh` có nội dung:

    ```bash
    sudo nano /usr/local/bin/backup_graylog.sh
    ```
    - Nội dung file:

    ```bash
    #!/bin/bash
    #/usr/local/bin/backup_graylog.sh

    set -e

    # ==============================
    # Graylog Backup Script
    # ==============================

    BACKUP_DIR="/backup/graylog"
    DATE=$(date +%Y%m%d_%H%M%S)

    INSTALL_DIR="/opt/graylog-stack"

    GRAYLOG_DATA="/data/graylog"
    MONGO_DATA="/data/mongodb"
    OPENSEARCH_DATA="/data/opensearch"


    echo "======================================"
    echo " Graylog Backup $DATE"
    echo "======================================"


    mkdir -p ${BACKUP_DIR}


    echo "[1/5] Stop Graylog stack..."

    cd ${INSTALL_DIR}

    docker compose stop


    echo "[2/5] Backup configuration..."

    tar czf \
    ${BACKUP_DIR}/graylog_config_${DATE}.tar.gz \
    ${INSTALL_DIR}



    echo "[3/5] Backup MongoDB..."

    tar czf \
    ${BACKUP_DIR}/graylog_mongodb_${DATE}.tar.gz \
    ${MONGO_DATA}



    echo "[4/5] Backup Graylog data..."

    tar czf \
    ${BACKUP_DIR}/graylog_data_${DATE}.tar.gz \
    ${GRAYLOG_DATA}



    echo "[5/5] Backup OpenSearch..."

    tar czf \
    ${BACKUP_DIR}/graylog_opensearch_${DATE}.tar.gz \
    ${OPENSEARCH_DATA}



    echo "Start Graylog..."

    docker compose up -d


    echo ""
    echo "======================================"
    echo " BACKUP DONE"
    echo " Location:"
    echo " ${BACKUP_DIR}"
    echo "======================================"

    du -sh ${BACKUP_DIR}/*
    ```

> Lưu file:
>  - Ctrl + O -> Enter
>  - Ctrl + X

#### - Cấp quyền cho file:

```bash
sudo chmod +x /usr/local/bin/backup_graylog.sh
```

#### - Test backup

```bash
sudo /usr/local/bin/backup_graylog.sh
```

- Kết quả có dạng

![alt text](image-2.png)

#### - Lập lịch backup mỗi ngày
> Nếu sai giờ cần chỉnh lại, [Cánh chỉnh giờ Ubuntu](Cach_chinh_gio_ubuntu.md)
- Tạo cron:

```bash
sudo crontab -e
```

- Thêm dòng vào cuối và lưu file

```bash
# chạy backup lúc 20 giờ 30 mỗi ngày
30 20 * * * /usr/local/bin/backup_graylog.sh >> /var/log/graylog_backup.log 2>&1
```
>   Giải thích:
>   - 30   = phút 30
>   - 20   = giờ 20
>   - *    = mỗi ngày
>   - *    = mỗi tháng
>   - *    = mọi thứ

- Kiểm tra đã lưu

```bash
sudo crontab -l
```

- Kích hoạt cron

```bash
sudo systemctl enable cron
sudo systemctl start cron
```
- Test cron

```bash
systemctl status cron
```

- Xem log backup

```bash
tail -f /var/log/graylog_backup.log
```

## 3. Cấu Hình Thiết Bị Gửi Log

[Tại đây - II. Log Source](<../../II. Log Source (Sender)>)





