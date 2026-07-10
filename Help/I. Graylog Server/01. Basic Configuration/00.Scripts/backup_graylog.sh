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