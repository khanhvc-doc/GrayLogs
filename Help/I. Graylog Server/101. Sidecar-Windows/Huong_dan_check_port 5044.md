# HƯỚNG DẪN CHECK PORT

## 1. Sửa docker-compose.yml

- Thêm dòng  `- "5044:5044/tcp"` vào file bên dưới ports:

```bash
cd /opt/graylog-stack

sudo nano docker-compose.yml
```
![alt text](image-1.png)

- Restart stack & kiểm tra 

```bash
sudo docker compose down
sudo docker compose up -d

sudo docker ps
```

![alt text](image-2.png)

## 2. Kiểm tra port 5044

```bash
tnc -ComputerName 192.168.0.111 -Port 5044
```

![alt text](image-3.png)

> Chú ý: 
> - Đảm bảo port 5044 phải được mở mới làm tiếp các bước khác
