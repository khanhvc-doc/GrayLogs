# LAYER 3 / CORE Switch

## 1. Phần cơ bản tương tự Layer 2:

- Archive log cấu hình
- Chỉnh giờ

## 2. Logging gửi về Graylog

> Noted:
> - Tăng buferred lên 32768
> - Đánh số thứ tự mỗi dòng log `service sequence-numbers`

```bash
conf t

logging origin-id string Server_Room_CoreSwitch_4507_IP_192.168.100.7

logging host 192.168.0.111 transport udp port 1514

logging trap informational

logging facility local6

logging source-interface Vlan1

logging buffered 32768 informational

logging on

service sequence-numbers

end
wr
```