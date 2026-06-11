#!/usr/bin/env bash
# =============================================================================
#  Graylog 5.x — Docker Compose Installer
#  Stack : Graylog 5.2 + MongoDB 6 + OpenSearch 2
#  OS    : Ubuntu 22.04 / 24.04
#  Usage : curl -s https://raw.githubusercontent.com/<YOU>/<REPO>/main/install_graylog.sh | sudo bash
# =============================================================================

set -euo pipefail

# ── Màu sắc terminal ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
banner()  { echo -e "\n${BOLD}${CYAN}$*${NC}\n"; }

# ── Kiểm tra root ─────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Script phải chạy với quyền root (sudo)."

# ── Biến cấu hình — chỉnh sửa tại đây nếu cần ───────────────────────────────
INSTALL_DIR="/opt/graylog"
DATA_DIR="/data/graylog"                 # thư mục lưu data persistent
GRAYLOG_VERSION="4.3"
MONGO_VERSION="4.4"
OPENSEARCH_VERSION="2.12.0"
GRAYLOG_HTTP_PORT="9000"                 # Web UI
GRAYLOG_SYSLOG_UDP_PORT="1514"          # Syslog UDP input (tuỳ chọn)
GRAYLOG_GELF_UDP_PORT="12201"           # GELF UDP input (tuỳ chọn)
TIMEZONE="Asia/Ho_Chi_Minh"

# ── Tự động sinh mật khẩu an toàn ────────────────────────────────────────────
# Dùng dd thay vì tr|head để tránh SIGPIPE với set -euo pipefail
_rnd() { LC_ALL=C tr -dc "$1" </dev/urandom 2>/dev/null | dd bs=1 count="$2" 2>/dev/null || true; }
GRAYLOG_PASSWORD_SECRET=$(_rnd 'A-Za-z0-9' 96)
GRAYLOG_ADMIN_PASSWORD="admin"
GRAYLOG_ROOT_PASSWORD_SHA2=$(printf '%s' "${GRAYLOG_ADMIN_PASSWORD}" | sha256sum | cut -d' ' -f1)

# ── Lấy IP host ───────────────────────────────────────────────────────────────
HOST_IP=$(hostname -I | awk '{print $1}')

# =============================================================================
banner "═══════════════════════════════════════════════════"
banner "   Graylog ${GRAYLOG_VERSION} — Docker Installer"
banner "═══════════════════════════════════════════════════"
# =============================================================================

# ── 1. Kiểm tra & cài Docker ─────────────────────────────────────────────────
banner "▶ Bước 1/5 — Kiểm tra Docker"

if ! command -v docker &>/dev/null; then
    info "Docker chưa được cài. Đang cài..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
    success "Docker đã cài xong."
else
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    success "Docker đã có sẵn (${DOCKER_VER})."
fi

# Kiểm tra docker compose v2
if ! docker compose version &>/dev/null; then
    apt-get install -y -qq docker-compose-plugin
fi
success "Docker Compose plugin OK."

# ── 2. Tuning OS — bắt buộc cho OpenSearch ───────────────────────────────────
banner "▶ Bước 2/5 — Tuning OS (vm.max_map_count)"

CURRENT_MAP=$(sysctl -n vm.max_map_count)
if [[ ${CURRENT_MAP} -lt 262144 ]]; then
    sysctl -w vm.max_map_count=262144 > /dev/null
    grep -q 'vm.max_map_count' /etc/sysctl.conf \
        && sed -i 's/.*vm.max_map_count.*/vm.max_map_count=262144/' /etc/sysctl.conf \
        || echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
    success "vm.max_map_count đã set = 262144."
else
    success "vm.max_map_count = ${CURRENT_MAP} (OK)."
fi

# ── 3. Tạo thư mục ───────────────────────────────────────────────────────────
banner "▶ Bước 3/5 — Tạo thư mục"

mkdir -p "${INSTALL_DIR}"
mkdir -p "${DATA_DIR}"/{mongodb,opensearch,graylog-data,graylog-journal}

# OpenSearch cần quyền ghi từ uid 1000
chown -R 1000:1000 "${DATA_DIR}/opensearch"

success "Thư mục: ${INSTALL_DIR}  |  Data: ${DATA_DIR}"

# ── 4. Tạo file cấu hình ─────────────────────────────────────────────────────
banner "▶ Bước 4/5 — Tạo docker-compose.yml & .env"

# ── .env ──────────────────────────────────────────────────────────────────────
cat > "${INSTALL_DIR}/.env" <<ENV
# ===================== Graylog Environment =====================
GRAYLOG_VERSION=${GRAYLOG_VERSION}
MONGO_VERSION=${MONGO_VERSION}
OPENSEARCH_VERSION=${OPENSEARCH_VERSION}

# Thư mục data
DATA_DIR=${DATA_DIR}

# Mạng & port
HOST_IP=${HOST_IP}
GRAYLOG_HTTP_PORT=${GRAYLOG_HTTP_PORT}
GRAYLOG_SYSLOG_UDP_PORT=${GRAYLOG_SYSLOG_UDP_PORT}
GRAYLOG_GELF_UDP_PORT=${GRAYLOG_GELF_UDP_PORT}

# Bảo mật — KHÔNG chia sẻ file này
GRAYLOG_PASSWORD_SECRET=${GRAYLOG_PASSWORD_SECRET}
GRAYLOG_ROOT_PASSWORD_SHA2=${GRAYLOG_ROOT_PASSWORD_SHA2}

# Timezone
TIMEZONE=${TIMEZONE}
ENV

chmod 600 "${INSTALL_DIR}/.env"

# ── docker-compose.yml ────────────────────────────────────────────────────────
cat > "${INSTALL_DIR}/docker-compose.yml" <<'COMPOSE'
version: "3.8"

networks:
  graylog-net:
    driver: bridge

volumes:
  mongodb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR}/mongodb
  opensearch_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR}/opensearch
  graylog_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR}/graylog-data
  graylog_journal:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_DIR}/graylog-journal

services:

  # ── MongoDB ────────────────────────────────────────────────
  mongodb:
    image: mongo:${MONGO_VERSION}
    container_name: graylog-mongodb
    restart: unless-stopped
    networks:
      - graylog-net
    volumes:
      - mongodb_data:/data/db
    environment:
      TZ: ${TIMEZONE}
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

  # ── OpenSearch ─────────────────────────────────────────────
  opensearch:
    image: opensearchproject/opensearch:${OPENSEARCH_VERSION}
    container_name: graylog-opensearch
    restart: unless-stopped
    networks:
      - graylog-net
    volumes:
      - opensearch_data:/usr/share/opensearch/data
    environment:
      TZ: ${TIMEZONE}
      cluster.name: graylog
      node.name: opensearch-node1
      discovery.type: single-node
      bootstrap.memory_lock: "true"
      OPENSEARCH_JAVA_OPTS: "-Xms1g -Xmx1g"
      DISABLE_SECURITY_PLUGIN: "true"         # nội bộ, không expose ra ngoài
      DISABLE_INSTALL_DEMO_CONFIG: "true"
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s

  # ── Graylog ────────────────────────────────────────────────
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
      - graylog_data:/usr/share/graylog/data
      - graylog_journal:/usr/share/graylog/data/journal
    environment:
      TZ: ${TIMEZONE}
      GRAYLOG_NODE_ID_FILE: /usr/share/graylog/data/node-id
      GRAYLOG_HTTP_BIND_ADDRESS: "0.0.0.0:9000"
      GRAYLOG_HTTP_EXTERNAL_URI: "http://${HOST_IP}:${GRAYLOG_HTTP_PORT}/"
      GRAYLOG_ELASTICSEARCH_HOSTS: "http://opensearch:9200"
      GRAYLOG_MONGODB_URI: "mongodb://mongodb:27017/graylog"
      GRAYLOG_PASSWORD_SECRET: ${GRAYLOG_PASSWORD_SECRET}
      GRAYLOG_ROOT_PASSWORD_SHA2: ${GRAYLOG_ROOT_PASSWORD_SHA2}
      GRAYLOG_ROOT_TIMEZONE: ${TIMEZONE}
      GRAYLOG_JOURNAL_DIR: /usr/share/graylog/data/journal
      # Tắt telemetry (tuỳ chọn)
      GRAYLOG_TELEMETRY_ENABLED: "false"
    ports:
      - "${GRAYLOG_HTTP_PORT}:9000"          # Web UI
      - "${GRAYLOG_SYSLOG_UDP_PORT}:1514/udp" # Syslog UDP
      - "${GRAYLOG_SYSLOG_UDP_PORT}:1514/tcp" # Syslog TCP
      - "${GRAYLOG_GELF_UDP_PORT}:12201/udp" # GELF UDP
      - "${GRAYLOG_GELF_UDP_PORT}:12201/tcp" # GELF TCP
    entrypoint: /usr/bin/tini -- wait-for-it opensearch:9200 -t 120 -- /docker-entrypoint.sh
COMPOSE

success "Đã tạo docker-compose.yml và .env"

# ── 5. Khởi động stack ───────────────────────────────────────────────────────
banner "▶ Bước 5/5 — Khởi động Graylog Stack"

cd "${INSTALL_DIR}"
docker compose pull
docker compose up -d

# ── Chờ Graylog sẵn sàng ─────────────────────────────────────────────────────
info "Chờ Graylog khởi động (tối đa 3 phút)..."
TIMEOUT=180; ELAPSED=0; READY=0
while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:${GRAYLOG_HTTP_PORT}/api" 2>/dev/null || echo "000")
    if [[ "${HTTP_CODE}" == "200" || "${HTTP_CODE}" == "401" ]]; then
        READY=1; break
    fi
    sleep 5; ELAPSED=$((ELAPSED + 5))
    echo -ne "  ${ELAPSED}s / ${TIMEOUT}s ...\r"
done

echo ""

# ── Tạo systemd service để auto-start ────────────────────────────────────────
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
success "Systemd service 'graylog-stack' đã được kích hoạt."
# ── Script cập nhật IP khi IP host thay đổi ──────────────────────────────────
cat > /usr/local/bin/graylog-update-ip <<'UPDATEIP'
#!/usr/bin/env bash
# Cập nhật HOST_IP trong .env và restart Graylog khi IP thay đổi
ENV_FILE="/opt/graylog/.env"
COMPOSE_DIR="/opt/graylog"
NEW_IP=$(hostname -I | awk '{print $1}')
OLD_IP=$(grep "^HOST_IP=" "${ENV_FILE}" | cut -d= -f2)
if [[ "${NEW_IP}" == "${OLD_IP}" ]]; then echo "[INFO] IP không đổi (${NEW_IP})."; exit 0; fi
echo "[INFO] IP thay đổi: ${OLD_IP} -> ${NEW_IP}"
sed -i "s|^HOST_IP=.*|HOST_IP=${NEW_IP}|" "${ENV_FILE}"
cd "${COMPOSE_DIR}" && docker compose up -d graylog
echo "[OK] Graylog restart với IP mới: ${NEW_IP}"
UPDATEIP
chmod +x /usr/local/bin/graylog-update-ip
(crontab -l 2>/dev/null | grep -v "graylog-update-ip"; echo "*/5 * * * * /usr/local/bin/graylog-update-ip >> /var/log/graylog-ip-update.log 2>&1") | crontab - || true
success "Script graylog-update-ip đã cài, cron chạy mỗi 5 phút."


# =============================================================================
LINE="═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BOLD}${GREEN}${LINE}${NC}"
echo -e "${BOLD}${GREEN}   ✅  GRAYLOG CÀI ĐẶT THÀNH CÔNG!${NC}"
echo -e "${BOLD}${GREEN}${LINE}${NC}"
echo ""

if [[ ${READY} -eq 0 ]]; then
    echo -e "  ${RED}⚠  Graylog chưa phản hồi sau ${TIMEOUT}s — kiểm tra log bên dưới${NC}"
else
    echo -e "  ${GREEN}● Trạng thái   :${NC}  ${BOLD}Đang chạy & sẵn sàng 🎉${NC}"
fi

echo ""
echo -e "${BOLD}${CYAN}  ┌─ THÔNG TIN ĐĂNG NHẬP ─────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}  │${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  🌐 Web UI   :  ${BOLD}http://${HOST_IP}:${GRAYLOG_HTTP_PORT}${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  👤 Username :  ${BOLD}admin${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  🔑 Password :  ${BOLD}${GRAYLOG_ADMIN_PASSWORD}${NC}"
echo -e "${BOLD}${CYAN}  │${NC}"
echo -e "${BOLD}${CYAN}  └────────────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${BOLD}${CYAN}  ┌─ CẤU HÌNH HỆ THỐNG ────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}  │${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  📁 Cài đặt  :  ${INSTALL_DIR}/docker-compose.yml"
echo -e "${BOLD}${CYAN}  │${NC}  🔐 Env file :  ${INSTALL_DIR}/.env  ${YELLOW}(chmod 600)${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  💾 Data     :  ${DATA_DIR}"
echo -e "${BOLD}${CYAN}  │${NC}"
echo -e "${BOLD}${CYAN}  └────────────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${BOLD}${CYAN}  ┌─ PORTS ─────────────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}  │${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  ${GRAYLOG_HTTP_PORT}/tcp          Web UI"
echo -e "${BOLD}${CYAN}  │${NC}  ${GRAYLOG_SYSLOG_UDP_PORT}/tcp,udp      Syslog input"
echo -e "${BOLD}${CYAN}  │${NC}  ${GRAYLOG_GELF_UDP_PORT}/tcp,udp    GELF input"
echo -e "${BOLD}${CYAN}  │${NC}"
echo -e "${BOLD}${CYAN}  └────────────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "${BOLD}${CYAN}  ┌─ LỆNH QUẢN LÝ ─────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}${CYAN}  │${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  cd ${INSTALL_DIR}"
echo -e "${BOLD}${CYAN}  │${NC}  docker compose ps            ${CYAN}# trạng thái containers${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  docker compose logs -f       ${CYAN}# log realtime${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  docker compose down          ${CYAN}# dừng stack${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  docker compose up -d         ${CYAN}# khởi động lại${NC}"
echo -e "${BOLD}${CYAN}  │${NC}  sudo graylog-update-ip       ${CYAN}# cập nhật IP thủ công${NC}"
echo -e "${BOLD}${CYAN}  │${NC}"
echo -e "${BOLD}${CYAN}  └────────────────────────────────────────────────────────────┘${NC}"
echo ""
if [[ ${READY} -eq 0 ]]; then
    echo -e "  ${YELLOW}→ Kiểm tra log: cd ${INSTALL_DIR} && docker compose logs -f graylog${NC}"
    echo ""
fi
echo -e "${BOLD}${GREEN}${LINE}${NC}"
echo ""
