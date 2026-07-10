# GRAYLOG 6.1

## I. CHUẨN BỊ

### 1. Cầu hình

```bash
VPS
├── CPU 8 Core
├── RAM 16GB
├── OS Disk 100GB
├── Data Disk 500GB
└── Backup Disk 50GB

Ubuntu 24.04
└── Docker Compose
     ├── Graylog
     ├── OpenSearch
     └── MongoDB

Volumes
├── /data/opensearch
├── /data/mongodb
├── /data/graylog
└── /backup
```

### 2. Partition đề xuất

#### 2.1 Disk OS

- Disk1 100GB

```bash
/
├── Ubuntu
├── Docker Engine
├── Docker Compose
└── configs
```

- Chi tiết

| Mount | Size | Mục đích        |
| ----- | ---: | --------------- |
| EFI   |  1GB | boot UEFI       |
| /boot |  2GB | kernel          |
| /     | 85GB | Ubuntu + Docker |
| swap  |  8GB | chống thiếu RAM |
| free  | ~4GB | dự phòng        |

#### 2.2 Disk Data

Disk 2: 500GB

```bash
/data
|
├── graylog
├── opensearch
└── mongodb
```

#### 2.3 Disk Backup

Disk 3: 50GB

```bash
/backup
 |
 ├── compose backup
 ├── config export
 └── script
```

## II. CÀI ĐẶT

### 1. Cài Docker

```bash
curl -s https://raw.githubusercontent.com/khanhvc-doc/GrayLogs/refs/heads/master/install_docker.sh | sudo bash
```
#### - Kiểm tra đảm bảo docker cài thành công

```bash
sudo docker info | grep "Docker Root Dir"
```

#### - Kết quả mong đợi

```bash
Docker Root Dir: /data/docker
sudo ls -l /data/docker
```

### 2. Prepare graylog

```bash
curl -s https://raw.githubusercontent.com/khanhvc-doc/GrayLogs/refs/heads/master/prepare_graylog_docker_foundation.sh | sudo bash

```

### 3. Cài graylog

```bash
curl -s https://raw.githubusercontent.com/khanhvc-doc/GrayLogs/refs/heads/master/install_graylog.sh | sudo bash

```

## III. T-Shoot

- Thông tin đăng nhập mặt định

```bash

  Web UI      : http://< là địa chỉ IP của Ubuntu >:9000
  Username    : admin
  Password    : admin
```
> - NOTED: 
>    - Đẩy log về là port 1514 vì chạy trong docker
>    - Có 1 số trường hợp bị lỗi do CPU **không hỗ trợ MONGO 6**
>    - Cập nhật địa chỉ IP mới cho graylog bằng lệnh ```sudo graylog-update-ip```


- Thông tin quản lý
```bash
# Ví dụ IP của máy graylog 192.168.0.66
  Web UI      : http://192.168.0.66:9000
  Username    : admin
  Password    : admin

  Ports:
    9000/tcp          Web UI
    1514/udp|tcp      Syslog
    12201/udp|tcp    GELF

  Cisco syslog config:
    logging host 192.168.0.66 transport udp port 1514

  File cau hinh:
    /opt/graylog-stack/.env
    /opt/graylog-stack/docker-compose.yml

  Volumes:
    /data/graylog/config    graylog.conf
    /data/graylog/data      Graylog data
    /data/graylog/journal   Message journal
    /data/opensearch        Index data (6GB JVM)
    /data/mongodb           Config database

  Quan ly:
    cd /opt/graylog-stack
    docker compose ps
    docker compose logs -f graylog
    docker compose logs -f opensearch
    docker compose logs -f mongodb
    docker compose down
    docker compose up -d

[WARN]  Timeout. Kiem tra log:
    cd /opt/graylog-stack && sudo docker compose logs --tail=50 graylog

```
## IV. HOẶC tải file OVA về import dùng luôn (VMWare Ver 16.2.1 1881642 - VMWare Pro)

- Link: https://drive.google.com/file/d/1wi0jJwd0WYr-zCsGGJ1PF8IQ_ZMEPpbP/view?usp=drive_link

- Thông tin login sau khi import thành công:
     - GRAYLOG_VERSION="6.1"
     - MONGO_VERSION="6.0"
     - OPENSEARCH_VERSION="2.12.0"
     - Port nhận log của server là: **1514** 
- **Ubuntu**: sadmin/sadmin
- **URL**: http:// < là địa chỉ IP của Ubuntu >:9000
- **ID/Password**: admin/admin

