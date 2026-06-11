# Graylog 5.2

## Cầu hình
Yêu cầu:
RAM: 4Gb
CPU: 2
HDD: 100Gg
Card mạng: 1 - Brigde (nếu vmware)


1. Cài Docker
```bash
curl -s https://raw.githubusercontent.com/khanhvc-doc/zabbix/master/install_docker.sh | sudo bash
```
Kiểm tra đảm bảo docker cài thành công
sudo docker info | grep "Docker Root Dir"

# kết quả mong đợi
Docker Root Dir: /data/docker
sudo ls -l /data/docker

2. Cài GrayLog
```bash
curl -s https://raw.githubusercontent.com/khanhvc-doc/GrayLogs/refs/heads/master/install_graylog.sh | sudo bash
# \
#  -o /tmp/gl.sh && sudo bash /tmp/gl.sh

```
##
Thông tin đăng nhập
  👤 Username :  admin
  🔑 Password :  admin

- Nếu muốn chạy tay ngay khi biết IP vừa đổi:
```bash
  sudo graylog-update-ip


  # Xem IP thực tế hiện tại
ip addr show | grep 'inet '

# Xem IP đang lưu trong .env
grep HOST_IP /opt/graylog/.env

```
- Kiểm tra port đang lắng nghe
```bash
sudo docker compose -f /opt/graylog/docker-compose.yml ps
sudo ss -tlunp | grep -E '9000|1514|12201'
```


