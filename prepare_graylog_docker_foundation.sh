#!/bin/bash
set -e

echo "============================================================"
echo " PREPARE DOCKER FOUNDATION FOR GRAYLOG"
echo "============================================================"


# ===============================
# Check mount
# ===============================

echo ""
echo "[1/8] Checking storage..."

for DIR in /data /backup
do
    if mountpoint -q $DIR
    then
        echo "OK: $DIR mounted"
    else
        echo "ERROR: $DIR not mounted"
        exit 1
    fi
done



# ===============================
# Create directory structure
# ===============================

echo ""
echo "[2/8] Install utility tools..."

sudo apt install -y tree

sudo mkdir -p /opt/graylog-stack

sudo mkdir -p /data/docker

sudo mkdir -p /data/graylog
sudo mkdir -p /data/opensearch
sudo mkdir -p /data/mongodb

sudo mkdir -p /backup/graylog

echo ""
echo "Current directory structure:"
echo ""

echo "===== /opt/graylog-stack ====="
tree /opt/graylog-stack

echo ""
echo "===== /data ====="
tree -L 2 /data

echo ""
echo "===== /backup ====="
tree -L 2 /backup

echo ""
echo "===== Mount check ====="

df -h | egrep "/data|/backup|/$"
# ===============================
# Docker daemon config
# ===============================

echo ""
echo "[3/8] Configure Docker daemon..."


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



# ===============================
# OpenSearch kernel requirement
# ===============================

echo ""
echo "[4/8] Configure OpenSearch kernel..."


sudo tee /etc/sysctl.d/99-opensearch.conf > /dev/null <<EOF
vm.max_map_count=262144
EOF


sudo sysctl --system



# ===============================
# Permission
# ===============================

echo ""
echo "[5/8] Configure permission..."

sudo mkdir -p /data/graylog/config
sudo chown -R 1100:1100 /data/graylog
# sudo chown -R 1000:1000 /data/graylog
sudo chown -R 1000:1000 /data/opensearch
sudo chown -R 999:999 /data/mongodb




# ===============================
# Create environment template
# ===============================

echo ""
echo "[6/8] Create .env template..."


sudo tee /opt/graylog-stack/.env > /dev/null <<EOF

# ==========================
# Graylog
# ==========================

GRAYLOG_HTTP_BIND_ADDRESS=0.0.0.0:9000

GRAYLOG_PASSWORD_SECRET=

GRAYLOG_ROOT_PASSWORD_SHA2=



# ==========================
# MongoDB
# ==========================

MONGO_INITDB_ROOT_USERNAME=graylog

MONGO_INITDB_ROOT_PASSWORD=



# ==========================
# OpenSearch
# ==========================

OPENSEARCH_JAVA_OPTS=-Xms6g -Xmx6g

EOF



# ===============================
# Docker test
# ===============================

echo ""
echo "[7/8] Docker verification..."


docker info | grep "Docker Root Dir"

docker compose version



# ===============================
# Summary
# ===============================

echo ""
echo "[8/8] Completed"

echo ""
echo "============================================================"
echo " READY FOR GRAYLOG DEPLOYMENT"
echo "============================================================"

echo ""
echo "Structure:"
echo ""
echo "/opt/graylog-stack"
echo " └── .env"
echo ""
echo "/data"
echo " ├── docker"
echo " ├── graylog"
echo " ├── opensearch"
echo " └── mongodb"
echo ""
echo "/backup"
echo " └── graylog"
echo ""

echo "Next step:"
echo "Create docker-compose.yml"
echo "============================================================"