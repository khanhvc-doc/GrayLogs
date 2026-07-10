#!/bin/bash
set -e

echo "================================================================"
echo " CÀI ĐẶT DOCKER CHO GRAYLOG SERVER"
echo "================================================================"


echo ""
echo "[1/6] Update hệ thống..."

sudo apt update
sudo apt upgrade -y


echo ""
echo "[2/6] Cài package cần thiết..."

sudo apt install -y \
ca-certificates \
curl \
gnupg \
lsb-release


echo ""
echo "[3/6] Add Docker Repository..."

sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
| sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg


echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


sudo apt update


echo ""
echo "[4/6] Cài Docker Engine..."

sudo apt install -y \
docker-ce \
docker-ce-cli \
containerd.io \
docker-buildx-plugin \
docker-compose-plugin


sudo docker --version

echo ""
echo "Docker Compose:"
docker compose version



echo ""
echo "[5/6] Cấu hình Docker data-root sang /data/docker..."


if [ ! -d "/data" ]; then
    echo "ERROR: /data không tồn tại"
    echo "Hãy mount disk data trước khi chạy script"
    exit 1
fi


sudo mkdir -p /data/docker


sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "/data/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF


sudo systemctl restart docker
sudo systemctl enable docker



echo ""
echo "[6/6] Add user vào group docker..."

sudo usermod -aG docker $USER



echo ""
echo "================================================================"
echo " ✅ DOCKER INSTALL HOÀN TẤT"
echo ""
echo " Docker Root:"
echo " /data/docker   (Disk 500GB)"
echo ""
echo " Kiểm tra sau logout/login:"
echo ""
echo " docker info | grep 'Docker Root Dir'"
echo ""
echo " docker compose version"
echo ""
echo " Vui lòng LOGOUT và LOGIN lại để áp dụng group docker"
echo "================================================================"