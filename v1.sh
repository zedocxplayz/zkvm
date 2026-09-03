#!/usr/bin/env bash

# ============================================================
# ZKVM PANEL V1 — ULTRA INSTALLER
# Production-ready installer for the ZKVM executable
# ============================================================

set -Eeuo pipefail

# ============================================================
# COLORS
# ============================================================

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
MAGENTA='\e[1;35m'
WHITE='\e[1;37m'
NC='\e[0m'

# ============================================================
# CONFIGURATION
# ============================================================

APP_NAME="ZKVM"
SERVICE_NAME="zkvm"

INSTALL_DIR="/opt/zkvm"
BIN_FILE="${INSTALL_DIR}/hkvm"
LOG_FILE="/var/log/zkvm.log"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

DOWNLOAD_URL="link catbox "

PANEL_PORT="8080"
MIN_FILE_SIZE_MB="30"

# ============================================================
# HELPERS
# ============================================================

line() {
    echo -e "${MAGENTA}============================================================${NC}"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

die() {
    error "$*"
    exit 1
}

cleanup() {
    rm -f "${INSTALL_DIR}/zkvm.download" 2>/dev/null || true
}

trap cleanup EXIT

# ============================================================
# LOGO
# ============================================================

clear

echo -e "${CYAN}"

cat <<'EOF'
███████╗██╗  ██╗██╗   ██╗███╗   ███╗
╚══███╔╝██║ ██╔╝██║   ██║████╗ ████║
  ███╔╝ █████╔╝ ██║   ██║██╔████╔██║
 ███╔╝  ██╔═██╗ ╚██╗ ██╔╝██║╚██╔╝██║
███████╗██║  ██╗ ╚████╔╝ ██║ ╚═╝ ██║
╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚═╝     ╚═╝

             ZKVM PANEL V1
          ULTRA INSTALLER

EOF

echo -e "${NC}"

line

# ============================================================
# ROOT CHECK
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
    die "Please run this installer as root."
fi

ok "Root access detected."

# ============================================================
# OS DETECTION
# ============================================================

if [[ ! -f /etc/os-release ]]; then
    die "Unable to detect operating system."
fi

# shellcheck disable=SC1091
source /etc/os-release

DISTRO="${ID:-unknown}"
VERSION="${VERSION_ID:-unknown}"
ARCH="$(uname -m)"
KERNEL="$(uname -r)"

info "Operating System : ${PRETTY_NAME:-${DISTRO} ${VERSION}}"
info "Architecture     : ${ARCH}"
info "Kernel           : ${KERNEL}"

line

# ============================================================
# ARCHITECTURE CHECK
# ============================================================

case "${ARCH}" in
    x86_64|amd64)
        ARCH_NAME="x86_64"
        ;;
    aarch64|arm64)
        ARCH_NAME="arm64"
        ;;
    armv7l|armv7*)
        ARCH_NAME="armv7"
        ;;
    *)
        warn "Unknown architecture: ${ARCH}"
        warn "The HKVM executable may not be compatible."
        ;;
esac

info "Detected architecture: ${ARCH_NAME:-${ARCH}}"

line

# ============================================================
# DEPENDENCIES
# ============================================================

info "Checking required utilities..."

REQUIRED_COMMANDS=(
    curl
    wget
    chmod
    file
    awk
    sed
    grep
)

MISSING=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        MISSING+=("${cmd}")
    fi
done

if (( ${#MISSING[@]} > 0 )); then

    info "Installing missing dependencies: ${MISSING[*]}"

    if command -v apt-get >/dev/null 2>&1; then

        export DEBIAN_FRONTEND=noninteractive

        apt-get update -y

        apt-get install -y \
            curl wget file \
            ca-certificates \
            lsof \
            procps \
            iproute2 \
            sudo

    elif command -v dnf >/dev/null 2>&1; then

        dnf install -y \
            curl wget file \
            ca-certificates \
            lsof \
            procps-ng \
            iproute \
            sudo

    elif command -v yum >/dev/null 2>&1; then

        yum install -y \
            curl wget file \
            ca-certificates \
            lsof \
            procps \
            iproute \
            sudo

    elif command -v pacman >/dev/null 2>&1; then

        pacman -Sy --noconfirm \
            curl wget file \
            ca-certificates \
            lsof \
            procps \
            iproute2 \
            sudo

    elif command -v apk >/dev/null 2>&1; then

        apk update

        apk add \
            curl wget file \
            ca-certificates \
            lsof \
            procps \
            iproute2 \
            sudo

    elif command -v zypper >/dev/null 2>&1; then

        zypper --non-interactive refresh

        zypper --non-interactive install \
            curl wget file \
            ca-certificates \
            lsof \
            procps \
            iproute2 \
            sudo

    else
        die "Unsupported Linux package manager."
    fi

else
    ok "All required utilities are available."
fi

line

# ============================================================
# SYSTEMD CHECK
# ============================================================

SYSTEMD_AVAILABLE="false"

if command -v systemctl >/dev/null 2>&1 &&
   [[ -d /run/systemd/system ]]; then
    SYSTEMD_AVAILABLE="true"
    ok "systemd detected."
else
    warn "systemd was not detected."
    warn "ZKVM will be installed without a systemd service."
fi

line

# ============================================================
# PORT CHECK
# ============================================================

info "Checking TCP port ${PANEL_PORT}..."

PORT_IN_USE="false"

if command -v ss >/dev/null 2>&1; then
    if ss -ltn "( sport = :${PANEL_PORT} )" 2>/dev/null |
        grep -q ":${PANEL_PORT}"; then
        PORT_IN_USE="true"
    fi
elif command -v lsof >/dev/null 2>&1; then
    if lsof -nP -iTCP:"${PANEL_PORT}" -sTCP:LISTEN \
        >/dev/null 2>&1; then
        PORT_IN_USE="true"
    fi
fi

if [[ "${PORT_IN_USE}" == "true" ]]; then

    warn "TCP port ${PANEL_PORT} is already in use."

    echo

    if command -v ss >/dev/null 2>&1; then
        ss -ltnp 2>/dev/null |
            grep ":${PANEL_PORT}" || true
    elif command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"${PANEL_PORT}" -sTCP:LISTEN || true
    fi

    echo

    read -r -p "Continue installation anyway? [y/N]: " CONFIRM

    if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
        die "Installation cancelled."
    fi
fi

line

# ============================================================
# INSTALL DIRECTORY
# ============================================================

info "Preparing ${INSTALL_DIR}..."

mkdir -p "${INSTALL_DIR}"

chmod 755 "${INSTALL_DIR}"

cd "${INSTALL_DIR}"

ok "Installation directory ready."

line

# ============================================================
# STOP EXISTING SERVICE
# ============================================================

if [[ "${SYSTEMD_AVAILABLE}" == "true" ]] &&
   systemctl list-unit-files \
   | grep -q "^${SERVICE_NAME}\.service"; then

    info "Stopping existing ZKVM service..."

    systemctl stop "${SERVICE_NAME}" >/dev/null 2>&1 || true

    ok "Existing service stopped."
fi

# ============================================================
# DOWNLOAD
# ============================================================

info "Downloading ZKVM executable..."

TEMP_FILE="${INSTALL_DIR}/zkvm.download"

rm -f "${TEMP_FILE}"

curl \
    --fail \
    --location \
    --retry 5 \
    --retry-delay 3 \
    --connect-timeout 15 \
    --max-time 1800 \
    --progress-bar \
    --output "${TEMP_FILE}" \
    "${DOWNLOAD_URL}"

echo

# ============================================================
# DOWNLOAD VALIDATION
# ============================================================

if [[ ! -f "${TEMP_FILE}" ]]; then
    die "ZKVM download failed."
fi

if [[ ! -s "${TEMP_FILE}" ]]; then
    die "Downloaded ZKVM file is empty."
fi

FILE_SIZE_MB="$(du -m "${TEMP_FILE}" | awk '{print $1}')"

info "Downloaded size: ${FILE_SIZE_MB} MB"

if [[ "${FILE_SIZE_MB}" -lt "${MIN_FILE_SIZE_MB}" ]]; then
    error "Downloaded file is smaller than expected."
    file "${TEMP_FILE}" || true
    die "Possible invalid download detected."
fi

FILE_TYPE="$(file -b "${TEMP_FILE}" 2>/dev/null || true)"

info "File type: ${FILE_TYPE}"

if echo "${FILE_TYPE}" | grep -Eiq \
    'HTML|ASCII text|Unicode text|JSON'; then

    error "The download appears to be a webpage/text response."

    echo
    head -c 300 "${TEMP_FILE}" 2>/dev/null || true
    echo

    die "Invalid ZKVM executable received."
fi

# ============================================================
# INSTALL BINARY
# ============================================================

info "Installing ZKVM executable..."

rm -f "${BIN_FILE}"

mv "${TEMP_FILE}" "${BIN_FILE}"

chmod 755 "${BIN_FILE}"

if [[ ! -x "${BIN_FILE}" ]]; then
    die "Unable to make ZKVM executable."
fi

ok "HKVM executable installed:"
echo -e "    ${WHITE}${BIN_FILE}${NC}"

# ============================================================
# BASIC EXECUTABLE CHECK
# ============================================================

info "Validating executable..."

if command -v file >/dev/null 2>&1; then
    file "${BIN_FILE}"
fi

if command -v ldd >/dev/null 2>&1; then

    LDD_OUTPUT="$(ldd "${BIN_FILE}" 2>&1 || true)"

    if echo "${LDD_OUTPUT}" | grep -q "not a dynamic executable"; then
        info "ZKVM is statically linked."
    elif echo "${LDD_OUTPUT}" | grep -q "not found"; then
        warn "ZKVM may have missing shared libraries:"
        echo "${LDD_OUTPUT}"
    fi
fi

ok "Executable validation completed."

# ============================================================
# SECURE FILE PERMISSIONS
# ============================================================

info "Applying secure permissions..."

chmod 755 "${INSTALL_DIR}"
chmod 755 "${BIN_FILE}"

# Only root can modify the executable.
chown root:root "${BIN_FILE}"

ok "Executable ownership: root:root"

line

# ============================================================
# FIREWALL
# ============================================================

info "Configuring firewall for TCP ${PANEL_PORT}..."

if command -v ufw >/dev/null 2>&1; then
    ufw allow "${PANEL_PORT}/tcp" >/dev/null 2>&1 || true
    ok "UFW rule configured."
fi

if command -v firewall-cmd >/dev/null 2>&1; then

    firewall-cmd \
        --permanent \
        --add-port="${PANEL_PORT}/tcp" \
        >/dev/null 2>&1 || true

    firewall-cmd \
        --reload \
        >/dev/null 2>&1 || true

    ok "firewalld rule configured."
fi

if command -v iptables >/dev/null 2>&1; then

    if ! iptables -C INPUT \
        -p tcp \
        --dport "${PANEL_PORT}" \
        -j ACCEPT >/dev/null 2>&1; then

        iptables -I INPUT \
            -p tcp \
            --dport "${PANEL_PORT}" \
            -j ACCEPT >/dev/null 2>&1 || true
    fi

    ok "iptables rule checked."
fi

line

# ============================================================
# LOG FILE
# ============================================================

info "Preparing log file..."

touch "${LOG_FILE}"

chmod 640 "${LOG_FILE}"

chown root:root "${LOG_FILE}"

ok "Log file ready: ${LOG_FILE}"

# ============================================================
# SYSTEMD SERVICE
# ============================================================

if [[ "${SYSTEMD_AVAILABLE}" == "true" ]]; then

    info "Creating systemd service..."

    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=ZKVM Panel V2
Documentation=ZKVM Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

WorkingDirectory=${INSTALL_DIR}

ExecStart=${BIN_FILE}

Restart=always
RestartSec=5

User=root
Group=root

LimitNOFILE=1048576
LimitNPROC=65535
LimitCORE=infinity

StandardOutput=append:${LOG_FILE}
StandardError=append:${LOG_FILE}

# Security / isolation
NoNewPrivileges=false
PrivateTmp=false
ProtectSystem=false
ProtectHome=false

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "${SERVICE_FILE}"

    systemctl daemon-reload

    systemctl enable "${SERVICE_NAME}" >/dev/null 2>&1

    info "Starting HKVM service..."

    systemctl restart "${SERVICE_NAME}"

    sleep 5

    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        ok "ZKVM service is ONLINE."
    else

        error "ZKVM service failed to start."

        echo
        systemctl status "${SERVICE_NAME}" \
            --no-pager \
            --full || true

        echo
        echo "Recent logs:"
        journalctl \
            -u "${SERVICE_NAME}" \
            -n 50 \
            --no-pager || true

        exit 1
    fi

else

    warn "Starting ZKVM manually..."

    nohup "${BIN_FILE}" \
        >> "${LOG_FILE}" \
        2>&1 &

    HKVM_PID=$!

    sleep 3

    if kill -0 "${ZKVM_PID}" 2>/dev/null; then
        ok "ZKVM started successfully. PID: ${HKVM_PID}"
    else
        die "ZKVM failed to start. Check ${LOG_FILE}"
    fi
fi

line

# ============================================================
# PANEL STATUS
# ============================================================

sleep 2

PANEL_STATUS="OFFLINE"

if command -v ss >/dev/null 2>&1; then

    if ss -ltn 2>/dev/null |
        grep -q ":${PANEL_PORT}"; then
        PANEL_STATUS="ONLINE"
    fi

elif command -v lsof >/dev/null 2>&1; then

    if lsof -nP \
        -iTCP:"${PANEL_PORT}" \
        -sTCP:LISTEN >/dev/null 2>&1; then
        PANEL_STATUS="ONLINE"
    fi
fi

if [[ "${PANEL_STATUS}" == "ONLINE" ]]; then
    PANEL_STATUS_DISPLAY="${GREEN}ONLINE${NC}"
else
    PANEL_STATUS_DISPLAY="${RED}OFFLINE${NC}"
fi

# ============================================================
# PUBLIC IP
# ============================================================

info "Detecting server IP..."

PUBLIC_IP=""

PUBLIC_IP="$(curl -4 \
    -fsS \
    --max-time 10 \
    https://api.ipify.org 2>/dev/null || true)"

if [[ -z "${PUBLIC_IP}" ]]; then
    PUBLIC_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
fi

if [[ -z "${PUBLIC_IP}" ]]; then
    PUBLIC_IP="YOUR_SERVER_IP"
fi

# ============================================================
# VERSION / PROCESS INFO
# ============================================================

ZKVM_PROCESS="NOT RUNNING"

if pgrep -f "${BIN_FILE}" >/dev/null 2>&1; then
    ZKVM_PROCESS="RUNNING"
fi

# ============================================================
# FINAL SCREEN
# ============================================================

clear

echo -e "${GREEN}"

cat <<EOF

╔════════════════════════════════════════════════════════════╗
║                    ZKVM PANEL V1                          ║
║                  INSTALLATION COMPLETE                    ║
╚════════════════════════════════════════════════════════════╝

  STATUS              : ${PANEL_STATUS_DISPLAY}

  PANEL URL           : http://${PUBLIC_IP}:${PANEL_PORT}

  INSTALL DIRECTORY   : ${INSTALL_DIR}

  EXECUTABLE          : ${BIN_FILE}

  SERVICE             : ${SERVICE_NAME}

  PROCESS             : ${ZKVM_PROCESS}

  LOG FILE            : ${LOG_FILE}

──────────────────────────────────────────────────────────────

  SERVICE COMMANDS

  Start:
    systemctl start ${SERVICE_NAME}

  Stop:
    systemctl stop ${SERVICE_NAME}

  Restart:
    systemctl restart ${SERVICE_NAME}

  Status:
    systemctl status ${SERVICE_NAME}

──────────────────────────────────────────────────────────────

  LIVE LOGS

    journalctl -u ${SERVICE_NAME} -f

  OR

    tail -f ${LOG_FILE}

──────────────────────────────────────────────────────────────

  HKVM EXECUTABLE

    ${BIN_FILE}

──────────────────────────────────────────────────────────────

  INSTALLATION DIRECTORY

    ${INSTALL_DIR}

──────────────────────────────────────────────────────────────

  ONE-LINE INSTALLER

    bash <(curl -fsSL https://raw.githubusercontent.com/zedocxplayz/zkvm/main/v1.sh)

══════════════════════════════════════════════════════════════

EOF

echo -e "${NC}"

if [[ "${PANEL_STATUS}" == "ONLINE" ]]; then
    ok "HKVM Panel is running on port ${PANEL_PORT}."
else
    warn "HKVM was installed, but port ${PANEL_PORT} is not listening."
    warn "Check: journalctl -u ${SERVICE_NAME} -n 100 --no-pager"
fi

line

echo -e "${CYAN}HKVM installation finished.${NC}"
echo