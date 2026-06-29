#!/usr/bin/env bash
# =============================================================================
# Graylog Stack Deploy Script v2
# Chay SAU: install_docker.sh + prepare_graylog_docker_foundation.sh
#
# Foundation da co san:
#   /opt/graylog-stack/      (INSTALL_DIR)
#   /data/graylog            (chown 1000:1000)
#   /data/opensearch         (chown 1000:1000)
#   /data/mongodb            (chown 999:999)
#   /backup/graylog
#   Docker root -> /data/docker
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}"; }

[[ $EUID -ne 0 ]] && error "Can chay voi sudo."

# =============================================================================
# CAU HINH CO DINH
# =============================================================================
INSTALL_DIR="/opt/graylog-stack"
GRAYLOG_VERSION="6.1"
MONGO_VERSION="6.0"
OPENSEARCH_VERSION="2.12.0"
GRAYLOG_HTTP_PORT="9000"
GRAYLOG_SYSLOG_UDP_PORT="1514"
GRAYLOG_GELF_UDP_PORT="12201"
TIMEZONE="Asia/Ho_Chi_Minh"
MONGO_USER="graylog"
MONGO_PASSWORD="StrongGraylogMongo2024"

# admin / admin
GRAYLOG_ADMIN_PASSWORD="admin"
GRAYLOG_ROOT_PASSWORD_SHA2=$(printf '%s' "${GRAYLOG_ADMIN_PASSWORD}" | sha256sum | cut -d' ' -f1)
GRAYLOG_PASSWORD_SECRET=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | dd bs=1 count=96 2>/dev/null || true)
HOST_IP=$(hostname -I | awk '{print $1}')

# =============================================================================
echo ""
echo -e "${BOLD}${CYAN}======================================================${NC}"
echo -e "${BOLD}${CYAN}  Graylog ${GRAYLOG_VERSION} + MongoDB ${MONGO_VERSION} + OpenSearch ${OPENSEARCH_VERSION}${NC}"
echo -e "${BOLD}${CYAN}======================================================${NC}"

# =============================================================================
step "1/5 - Kiem tra foundation"
# =============================================================================

[[ -d "${INSTALL_DIR}" ]]   || error "${INSTALL_DIR} chua ton tai. Chay prepare_graylog_docker_foundation.sh truoc."
[[ -d "/data/graylog" ]]    || error "/data/graylog chua ton tai."
[[ -d "/data/opensearch" ]] || error "/data/opensearch chua ton tai."
[[ -d "/data/mongodb" ]]    || error "/data/mongodb chua ton tai."
[[ -d "/backup/graylog" ]]  || error "/backup/graylog chua ton tai."
mountpoint -q /data          || error "/data chua duoc mount."
docker info > /dev/null 2>&1 || error "Docker chua chay."
docker compose version > /dev/null 2>&1 || error "Docker Compose plugin chua co."

DOCKER_ROOT=$(docker info 2>/dev/null | grep "Docker Root Dir" | awk '{print $NF}')
if [[ "${DOCKER_ROOT}" == "/data/docker" ]]; then
    success "Docker Root Dir = /data/docker"
else
    warn "Docker Root Dir = ${DOCKER_ROOT} (mong doi /data/docker)"
fi
success "Foundation OK"

# =============================================================================
step "2/5 - Tao cau truc thu muc + graylog.conf"
# =============================================================================
# Graylog 6.x bat buoc file graylog.conf phai ton tai truoc khi start container

mkdir -p /data/graylog/config
mkdir -p /data/graylog/data
mkdir -p /data/graylog/journal
mkdir -p /data/graylog/log
mkdir -p /data/graylog/plugin

cat > /data/graylog/config/graylog.conf <<GRAYLOG_CONF
# Graylog configuration
# Cac gia tri quan trong duoc override boi environment variables trong docker-compose
is_master = true
node_id_file = /usr/share/graylog/data/node-id
password_secret = ${GRAYLOG_PASSWORD_SECRET}
root_password_sha2 = ${GRAYLOG_ROOT_PASSWORD_SHA2}
root_timezone = ${TIMEZONE}
http_bind_address = 0.0.0.0:9000
http_external_uri = http://${HOST_IP}:${GRAYLOG_HTTP_PORT}/
elasticsearch_hosts = http://opensearch:9200
mongodb_uri = mongodb://${MONGO_USER}:${MONGO_PASSWORD}@mongodb:27017/graylog?authSource=admin
output_batch_size = 500
output_flush_interval = 1
outputbuffer_processors = 3
processbuffer_processors = 5
inputbuffer_processors = 2
ring_size = 65536
inputbuffer_ring_size = 65536
message_journal_dir = /usr/share/graylog/data/journal
log_mode = file
gc_warning_threshold = 1s
data_dir = /usr/share/graylog/data
GRAYLOG_CONF

# Graylog 6.x chay voi UID 1100 (khac 5.x la 1000)
chown -R 1100:1100 /data/graylog
chown -R 1000:1000 /data/opensearch
chown -R 999:999   /data/mongodb

success "Da tao /data/graylog/config/graylog.conf (UID 1100)"

# =============================================================================
step "3/5 - Ghi .env"
# =============================================================================

if [[ -f "${INSTALL_DIR}/.env" ]]; then
    cp "${INSTALL_DIR}/.env" "${INSTALL_DIR}/.env.bak.$(date +%Y%m%d%H%M%S)"
    info "Da backup .env cu."
fi

cat > "${INSTALL_DIR}/.env" <<ENV
# ==========================
# Versions
# ==========================
GRAYLOG_VERSION=${GRAYLOG_VERSION}
MONGO_VERSION=${MONGO_VERSION}
OPENSEARCH_VERSION=${OPENSEARCH_VERSION}

# ==========================
# Graylog
# ==========================
GRAYLOG_HTTP_BIND_ADDRESS=0.0.0.0:9000
GRAYLOG_HTTP_EXTERNAL_URI=http://${HOST_IP}:${GRAYLOG_HTTP_PORT}/
GRAYLOG_PASSWORD_SECRET=${GRAYLOG_PASSWORD_SECRET}
GRAYLOG_ROOT_PASSWORD_SHA2=${GRAYLOG_ROOT_PASSWORD_SHA2}
GRAYLOG_HTTP_PORT=${GRAYLOG_HTTP_PORT}
GRAYLOG_SYSLOG_UDP_PORT=${GRAYLOG_SYSLOG_UDP_PORT}
GRAYLOG_GELF_UDP_PORT=${GRAYLOG_GELF_UDP_PORT}
TIMEZONE=${TIMEZONE}

# ==========================
# MongoDB
# ==========================
MONGO_INITDB_ROOT_USERNAME=${MONGO_USER}
MONGO_INITDB_ROOT_PASSWORD=${MONGO_PASSWORD}

# ==========================
# OpenSearch
# ==========================
OPENSEARCH_JAVA_OPTS=-Xms6g -Xmx6g
ENV

chmod 600 "${INSTALL_DIR}/.env"
success "Da ghi ${INSTALL_DIR}/.env"

# =============================================================================
step "4/5 - Tao docker-compose.yml"
# =============================================================================

cat > "${INSTALL_DIR}/docker-compose.yml" <<'COMPOSE'
networks:
  graylog-net:
    driver: bridge

services:

  mongodb:
    image: mongo:${MONGO_VERSION}
    container_name: graylog-mongodb
    restart: unless-stopped
    networks:
      - graylog-net
    volumes:
      - /data/mongodb:/data/db
    environment:
      TZ: ${TIMEZONE}
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_INITDB_ROOT_USERNAME}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_INITDB_ROOT_PASSWORD}
    healthcheck:
      test:
        - CMD
        - mongosh
        - "--eval"
        - "db.adminCommand('ping')"
        - "--username"
        - "${MONGO_INITDB_ROOT_USERNAME}"
        - "--password"
        - "${MONGO_INITDB_ROOT_PASSWORD}"
        - "--authenticationDatabase"
        - "admin"
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s

  opensearch:
    image: opensearchproject/opensearch:${OPENSEARCH_VERSION}
    container_name: graylog-opensearch
    restart: unless-stopped
    networks:
      - graylog-net
    volumes:
      - /data/opensearch:/usr/share/opensearch/data
    environment:
      TZ: ${TIMEZONE}
      cluster.name: graylog
      node.name: opensearch-node1
      discovery.type: single-node
      bootstrap.memory_lock: "true"
      OPENSEARCH_JAVA_OPTS: ${OPENSEARCH_JAVA_OPTS}
      DISABLE_SECURITY_PLUGIN: "true"
      DISABLE_INSTALL_DEMO_CONFIG: "true"
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    healthcheck:
      test:
        - CMD-SHELL
        - "curl -sf http://localhost:9200/_cluster/health || exit 1"
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s

  graylog:
    image: graylog/graylog:${GRAYLOG_VERSION}
    container_name: graylog
    restart: unless-stopped
    networks:
      - graylog-net
    depends_on:
      mongodb:
        condition: service_healthy
      opensearch:
        condition: service_healthy
    volumes:
      - /data/graylog/config:/usr/share/graylog/data/config
      - /data/graylog/data:/usr/share/graylog/data/data
      - /data/graylog/journal:/usr/share/graylog/data/journal
      - /data/graylog/log:/usr/share/graylog/data/log
      - /data/graylog/plugin:/usr/share/graylog/plugin
    environment:
      TZ: ${TIMEZONE}
      GRAYLOG_IS_MASTER: "true"
      GRAYLOG_NODE_ID_FILE: /usr/share/graylog/data/node-id
      GRAYLOG_HTTP_BIND_ADDRESS: ${GRAYLOG_HTTP_BIND_ADDRESS}
      GRAYLOG_HTTP_EXTERNAL_URI: ${GRAYLOG_HTTP_EXTERNAL_URI}
      GRAYLOG_ELASTICSEARCH_HOSTS: "http://opensearch:9200"
      GRAYLOG_MONGODB_URI: "mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@mongodb:27017/graylog?authSource=admin"
      GRAYLOG_PASSWORD_SECRET: ${GRAYLOG_PASSWORD_SECRET}
      GRAYLOG_ROOT_PASSWORD_SHA2: ${GRAYLOG_ROOT_PASSWORD_SHA2}
      GRAYLOG_ROOT_TIMEZONE: ${TIMEZONE}
      GRAYLOG_JOURNAL_DIR: /usr/share/graylog/data/journal
      GRAYLOG_LOG_DIR: /usr/share/graylog/data/log
      GRAYLOG_TELEMETRY_ENABLED: "false"
    ports:
      - "${GRAYLOG_HTTP_PORT}:9000"
      - "${GRAYLOG_SYSLOG_UDP_PORT}:1514/udp"
      - "${GRAYLOG_SYSLOG_UDP_PORT}:1514/tcp"
      - "${GRAYLOG_GELF_UDP_PORT}:12201/udp"
      - "${GRAYLOG_GELF_UDP_PORT}:12201/tcp"
    entrypoint: /usr/bin/tini -- wait-for-it opensearch:9200 -t 120 -- /docker-entrypoint.sh
COMPOSE

success "Da tao ${INSTALL_DIR}/docker-compose.yml"

# =============================================================================
step "5/5 - Khoi dong Graylog Stack"
# =============================================================================

cd "${INSTALL_DIR}"

# Dung stack cu neu dang chay
if docker compose ps --quiet 2>/dev/null | grep -q .; then
    info "Dung stack cu..."
    docker compose down --remove-orphans
    sleep 3
fi

info "Pulling images (lan dau co the mat 5-10 phut)..."
docker compose pull

info "Starting stack..."
docker compose up -d

# Cho Graylog ready voi countdown hien thi ro rang
info "Cho Graylog khoi dong (toi da 180 giay)..."
TIMEOUT=180
ELAPSED=0
READY=0

while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:${GRAYLOG_HTTP_PORT}/api" 2>/dev/null || echo "000")
    if [[ "${CODE}" == "200" || "${CODE}" == "401" ]]; then
        READY=1
        break
    fi
    REMAIN=$((TIMEOUT - ELAPSED))
    printf "\r  [%3d giay con lai] HTTP status: %s    " "${REMAIN}" "${CODE}"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done
printf "\n"

# =============================================================================
# Systemd service
# =============================================================================

cat > /etc/systemd/system/graylog-stack.service <<SYSTEMD
[Unit]
Description=Graylog Stack (Docker Compose)
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable graylog-stack.service > /dev/null 2>&1
success "Systemd graylog-stack.service: enabled (tu dong start sau reboot)"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${BOLD}${GREEN}======================================================${NC}"
if [[ ${READY} -eq 1 ]]; then
echo -e "${BOLD}${GREEN}  OK  GRAYLOG SAN SANG${NC}"
else
echo -e "${BOLD}${YELLOW}  WARN  GRAYLOG CHUA PHAN HOI - xem log ben duoi${NC}"
fi
echo -e "${BOLD}${GREEN}======================================================${NC}"
echo ""
echo -e "  ${BOLD}Web UI      :${NC} http://${HOST_IP}:${GRAYLOG_HTTP_PORT}"
echo -e "  ${BOLD}Username    :${NC} admin"
echo -e "  ${BOLD}Password    :${NC} admin"
echo ""
echo -e "  ${BOLD}Ports:${NC}"
echo -e "    ${GRAYLOG_HTTP_PORT}/tcp          Web UI"
echo -e "    ${GRAYLOG_SYSLOG_UDP_PORT}/udp|tcp      Syslog"
echo -e "    ${GRAYLOG_GELF_UDP_PORT}/udp|tcp    GELF"
echo ""
echo -e "  ${BOLD}Cisco syslog config:${NC}"
echo -e "    logging host ${HOST_IP} transport udp port 1514"
echo ""
echo -e "  ${BOLD}Volumes:${NC}"
echo -e "    /data/graylog/config    graylog.conf"
echo -e "    /data/graylog/data      Graylog data"
echo -e "    /data/graylog/journal   Message journal"
echo -e "    /data/opensearch        Index data (6GB JVM)"
echo -e "    /data/mongodb           Config database"
echo ""
echo -e "  ${BOLD}Quan ly:${NC}"
echo -e "    cd ${INSTALL_DIR}"
echo -e "    docker compose ps"
echo -e "    docker compose logs -f graylog"
echo -e "    docker compose logs -f opensearch"
echo -e "    docker compose logs -f mongodb"
echo -e "    docker compose down"
echo -e "    docker compose up -d"
echo ""

if [[ ${READY} -eq 0 ]]; then
    warn "Timeout. Kiem tra log:"
    echo -e "    ${CYAN}cd ${INSTALL_DIR} && docker compose logs --tail=50 graylog${NC}"
    echo ""
fi