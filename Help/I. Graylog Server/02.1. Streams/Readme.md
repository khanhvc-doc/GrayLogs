
# STREAMS

## - TẠO STREAMS TRÊN GRAYLOG

### 1. Mục đích:
- Phân nhóm thiết bị dựa vào các ký tự đầu source gửi về
- Trong ví dụ là lọc nhóm thiết bị có tên bắt đầu bằng chữ **Building1**
- Không lọc log mà hiển thị 100% log nhận được

> Chú ý:
> - Dựa vào `logging origin-id` **hostname**
> - HOẶC `logging origin-id string` **<do chúng ta định nghĩa>**
> - Hướng dẫn này dùng cho tên đã được chuẩn hóa, trong ví dụ là trên Cisco IOS với "logging origin-id string" (phần [99.Scripts](<../../II. Log Source (Sender)/99.Scripts>) cũng có)

### 2. Thực hiện:

- Tạo Streams

![alt text](image.png)

- Tạo Rule

![alt text](rule-1.png)

![alt text](rule-2.png)

- Thêm điểu kiện lọc

![alt text](image-2.png)

- Nhấn chữ Paused để chuyển trạng thái sang Running

![alt text](image-3.png)

- Thực hiện lọc

![alt text](image-4.png)