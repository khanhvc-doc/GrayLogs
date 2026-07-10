
# Cisco IOS Layer 2

## 1. CÀI ĐẶT TRÊN CISCO IOS

### 1.0 Bật tính năng ghi log khi thay đổi cấu hình

Tham khảo https://khanhvc.blogspot.com/2020/04/keylogger-archive-log.html

```bash
conf t
archive
log config
logging enable
notify syslog
exit
exit
end
wri
```

### 1.1 Cài đặt giờ

#### - Cài đặt giờ bằng tay

```bash
clock set 19:44:00 24 Jun 2026

conf t
clock timezone UTC +7 0
end
wri

```

#### - HOẶC thông qua NTP

```bash
conf t
clock timezone UTC +7 0
!
ip domain-lookup
! ip name-server 8.8.8.8
ip name-server 192.168.99.11

! ntp server time.google.com   <= cập nhật ngày giờ bằng tên miền
ntp server time.hansollvina.com
ntp server 192.168.99.10
end
show ntp associations
wri

```

### 1.2 Kiểm tra giờ đúng chưa
```bash
show clock

# sync thế nào
show ntp associations detail
```

### 2. Cấu hình đẩy log về Graylog

```bash
conf t

! đẩy hostname về để tiện lọc Streams
logging origin-id hostname

logging host 192.168.0.111 transport udp port 1514
logging trap informational

service timestamps debug datetime msec show-timezone
service timestamps log datetime msec show-timezone

logging source-interface Vlan1     
! # gắn facility rõ ràng, dễ filter  
logging facility local6         
! # buffer log local phòng khi mất kết nối      
logging buffered 16384 informational  

logging on

end
wri

```

#### 2.1 Kiểm tra thông tin đã cấu hình
```bash
! Trên Cisco — xem log đang gửi không
show logging | include 192.168.0.111
show logging | include trap

```
> Chú ý: Có thể làm tự động bằng code, tham khảo trong phần [99.Script](../99.Scripts)

