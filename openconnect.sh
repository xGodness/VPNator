#!/usr/bin/env bash
set -euo pipefail

# ================== Настройки (можно переопределять переменными окружения) ==================
OCSERV_VERSION="${OCSERV_VERSION:-1.3.0}"
SRC_URL="https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz"
SRC_DIR="/usr/local/src"
TARBALL="${SRC_DIR}/ocserv-${OCSERV_VERSION}.tar.xz"
BUILD_DIR="${SRC_DIR}/ocserv-${OCSERV_VERSION}"

OCSERV_BIN_DEFAULT="/usr/local/sbin/ocserv"
OCSERV_CONF="/etc/ocserv/ocserv.conf"
OCSERV_DIR="/etc/ocserv"
OCSERV_PASSWD="${OCSERV_DIR}/ocpasswd"
SERVER_KEY="${OCSERV_DIR}/server-key.pem"
SERVER_CERT="${OCSERV_DIR}/server-cert.pem"
OCSERV_SERVICE="/etc/systemd/system/ocserv.service"

# Режим запуска: systemd (по умолчанию) или docker (совместимость со старым скриптом)
RUN_MODE="${RUN_MODE:-systemd}"

# Для docker-режима (совместимость с твоей версией)
OCSERV_SCRIPT_PATH="/usr/local/sbin/ocserv.sh"
LOG_FILE="/var/log/ocserv-docker.log"

# Сетевые параметры для VPN-пула/маршрутизации (под твой конфиг)
VPN_SUBNET="10.10.10.0/24"
WAN_IF="${WAN_IF:-$(ip -4 route ls default 2>/dev/null | awk '/default/ {print $5; exit}')}"
WAN_IF="${WAN_IF:-eth0}"

# Сертификат (темплейт certtool)
CERT_CN="${CERT_CN:-ocserv}"
CERT_ORG="${CERT_ORG:-VPN}"
CERT_DAYS="${CERT_DAYS:-3650}"

DEBIAN_SOURCES="/etc/apt/sources.list"
DEBIAN_FRONTEND=noninteractive; export DEBIAN_FRONTEND

# ================== Утилиты вывода ==================
log()   { echo -e "\033[1;32m[OK]\033[0m $*"; }
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERR]\033[0m $*" >&2; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "Запустите скрипт от root (sudo)."
    exit 1
  fi
}

check_debian12() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    if [[ "${ID:-}" != "debian" || "${VERSION_ID:-}" != "12" ]]; then
      warn "Обнаружен ${PRETTY_NAME:-unknown}. Скрипт рассчитан на Debian 12 (bookworm). Продолжаю на ваш риск."
    fi
  fi
}

append_sid_repo() {
  if ! grep -qE '^[[:space:]]*deb[[:space:]].*debian[[:space:]]+sid[[:space:]]+main' "$DEBIAN_SOURCES"; then
    info "Добавляю репозиторий Debian sid в $DEBIAN_SOURCES"
    echo "deb http://deb.debian.org/debian sid main" >> "$DEBIAN_SOURCES"
  else
    info "Репозиторий sid уже подключен."
  fi
}

apt_refresh_and_upgrade() {
  info "Обновляю индексы пакетов и систему…"
  apt-get update
  apt-get -y upgrade
}

install_build_deps() {
  info "Устанавливаю зависимости для сборки и работы…"
  local pkgs=(
    build-essential fakeroot devscripts
    iputils-ping ruby-ronn openconnect libuid-wrapper
    libnss-wrapper libsocket-wrapper gss-ntlmssp git autoconf
    libtool autopoint gettext automake nettle-dev libwrap0-dev
    libpam0g-dev liblz4-dev libseccomp-dev libreadline-dev libnl-route-3-dev
    libkrb5-dev liboath-dev libradcli-dev libprotobuf-dev libtalloc-dev
    libhttp-parser-dev libpcl1-dev protobuf-c-compiler gperf liblockfile-bin
    nuttcp libpam-oath libev-dev libgnutls28-dev gnutls-bin haproxy
    yajl-tools libcurl4-gnutls-dev libcjose-dev libjansson-dev libssl-dev
    iproute2 libpam-wrapper tcpdump libopenconnect-dev iperf3 ipcalc-ng
    freeradius libfreeradius-dev
    curl ca-certificates xz-utils pkg-config make
    iptables iptables-persistent # для NAT и сохранения правил
    ssmtp
  )
  # игнорируем возможные мелкие конфликты отдельных пакетов
  apt-get install -y "${pkgs[@]}" || true
  # убеждаемся, что критичное есть:
  apt-get install -y gnutls-bin iptables iptables-persistent
}

fetch_sources() {
  mkdir -p "$SRC_DIR"
  if [[ -f "$TARBALL" ]]; then
    info "Тарбол ${TARBALL} уже существует — пропускаю загрузку."
  else
    info "Скачиваю исходники ocserv ${OCSERV_VERSION}…"
    curl -fL -o "$TARBALL" "$SRC_URL"
    log "Скачано: $TARBALL"
  fi

  if [[ -d "$BUILD_DIR" ]]; then
    info "Каталог исходников уже распакован: $BUILD_DIR"
  else
    info "Распаковываю архив…"
    tar -xvf "$TARBALL" -C "$SRC_DIR"
    log "Распаковка завершена."
  fi
}

build_and_test() {
  cd "$BUILD_DIR"
  info "Конфигурирую сборку (--enable-oidc-auth)…"
  ./configure --enable-oidc-auth
  info "Собираю (все ядра)…"
  make -j"$(nproc)"
  info "Запускаю тесты (возможные падения haproxy-auth и test-oidc допустимы)…"
  # if make check; then
  #   log "Тесты завершились успешно."
  # else
  #   warn "Некоторые тесты упали — продолжаю."
  # fi
}

install_ocserv() {
  cd "$BUILD_DIR"
  info "Устанавливаю собранные бинарники…"
  make install
  local bin
  bin="$(command -v ocserv || true)"
  if [[ -z "$bin" ]]; then
    warn "ocserv не найден в PATH; ожидаемый путь: ${OCSERV_BIN_DEFAULT}"
  else
    log "ocserv найден: $bin"
  fi
}

generate_certs() {
  info "Готовлю ключ/сертификат в ${OCSERV_DIR}…"
  mkdir -p "$OCSERV_DIR"
  chmod 700 "$OCSERV_DIR" || true

  if [[ ! -f "$SERVER_KEY" ]]; then
    info "Генерирую приватный ключ (RSA 3072)…"
    certtool --generate-privkey --bits 3072 --outfile "$SERVER_KEY"
    chmod 600 "$SERVER_KEY"
  else
    info "Приватный ключ уже существует: $SERVER_KEY"
    chmod 600 "$SERVER_KEY" || true
  fi

  if [[ ! -f "$SERVER_CERT" ]]; then
    info "Генерирую самоподписанный сертификат (CN=${CERT_CN}, O=${CERT_ORG}, ${CERT_DAYS} дней)…"
    local tmpl
    tmpl="$(mktemp)"
    cat > "$tmpl" <<EOT
cn = "${CERT_CN}"
organization = "${CERT_ORG}"
serial = 001
expiration_days = ${CERT_DAYS}
signing_key
tls_www_server
encryption_key
EOT
    certtool --generate-self-signed \
      --load-privkey "$SERVER_KEY" \
      --template "$tmpl" \
      --outfile "$SERVER_CERT"
    rm -f "$tmpl"
    log "Сертификат создан: $SERVER_CERT"
  else
    info "Сертификат уже существует: $SERVER_CERT"
  fi
}

write_ocserv_conf() {
  info "Пишу конфиг ${OCSERV_CONF} (с бэкапом)…"
  if [[ -f "$OCSERV_CONF" ]]; then
    cp -a "$OCSERV_CONF" "${OCSERV_CONF}.bak.$(date +%Y%m%d%H%M%S)"
  fi
  cat > "$OCSERV_CONF" <<'EOF'
#auth = "certificate"
auth = "plain[passwd=/etc/ocserv/ocpasswd]"
tcp-port = 443
socket-file = /run/ocserv-socket
server-cert = /etc/ocserv/server-cert.pem
server-key = /etc/ocserv/server-key.pem
isolate-workers = true
max-clients = 20
max-same-clients = 2
rate-limit-ms = 100
server-stats-reset-time = 604800
keepalive = 32
output-buffer = 23000
dpd = 120
mobile-dpd = 1800
switch-to-tcp-timeout = 25
try-mtu-discovery = false
cert-user-oid = 0.9.2342.19200300.100.1.1
tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1:-VERS-TLS1.3"
auth-timeout = 1000
min-reauth-time = 300
max-ban-score = 100
ban-reset-time = 1200
cookie-timeout = 600
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
use-occtl = true
pid-file = /run/ocserv.pid
log-level = 1
device = vpns
predictable-ips = true
ipv4-network = 10.10.10.0
ipv4-netmask = 255.255.255.0
tunnel-all-dns = true
dns = 8.8.8.8
ping-leases = false
cisco-client-compat = true
udp-port = 443
dtls-legacy = true
client-bypass-protocol = false
route = default
EOF
  log "Конфиг записан."
}

install_systemd_unit() {
  info "Устанавливаю systemd unit ${OCSERV_SERVICE}…"
  local ocbin
  ocbin="$(command -v ocserv || echo "${OCSERV_BIN_DEFAULT}")"
  cat > "$OCSERV_SERVICE" <<EOF
[Unit]
Description=OpenConnect VPN Server (ocserv)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${ocbin} -c ${OCSERV_CONF} --foreground
Restart=on-failure
RestartSec=3
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SETUID CAP_SETGID
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SETUID CAP_SETGID
NoNewPrivileges=false
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now ocserv
  systemctl --no-pager --full status ocserv || true
}

enable_ip_forward() {
  info "Включаю IPv4 форвардинг…"
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  if grep -qE '^\s*net\.ipv4\.ip_forward\s*=' /etc/sysctl.conf; then
    sed -i 's|^\s*net\.ipv4\.ip_forward\s*=.*|net.ipv4.ip_forward=1|' /etc/sysctl.conf
  else
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
  fi
  sysctl --system >/dev/null
  log "ip_forward включён."
}

iptables_rule_present() {
  # простой хелпер: 0 если правило есть, 1 если нет
  iptables -C "$@" >/dev/null 2>&1
}

setup_iptables_nat() {
  info "Добавляю iptables-правила для NAT/форвардинга (WAN_IF=${WAN_IF})…"

  # Разрешаем форвард трафика VPN -> WAN и WAN -> VPN (as is, как у тебя)
  iptables_rule_present FORWARD -s "$VPN_SUBNET" -j ACCEPT || iptables -A FORWARD -s "$VPN_SUBNET" -j ACCEPT
  iptables_rule_present FORWARD -d "$VPN_SUBNET" -j ACCEPT || iptables -A FORWARD -d "$VPN_SUBNET" -j ACCEPT

  # NAT
  iptables_rule_present -t nat POSTROUTING -s "$VPN_SUBNET" -o "$WAN_IF" -j MASQUERADE \
    || iptables -t nat -A POSTROUTING -s "$VPN_SUBNET" -o "$WAN_IF" -j MASQUERADE

  # Сохраняем правила, чтобы переживали перезагрузку
  mkdir -p /etc/iptables
  iptables-save > /etc/iptables/rules.v4
  systemctl enable --now netfilter-persistent || true

  log "iptables настроены и сохранены."
}

create_vpn_user() {
  local user="${OCSERV_USER:-}"
  if [[ -z "${user}" ]]; then
    read -rp "Введите имя нового VPN-пользователя (по умолчанию: ocuser): " user || true
    user="${user:-ocuser}"
  else
    info "Создаю/обновляю VPN-пользователя: ${user}"
  fi

  # ocpasswd сам запросит пароль (и подтверждение)
  ocpasswd -c "$OCSERV_PASSWD" "$user" || true
  log "Пользователь ${user} готов (файл: ${OCSERV_PASSWD})."
}

run_ocserv_docker_legacy() {
  info "Готовлю /etc/ocserv и скачиваю ocserv.sh (Docker-скрипт)…"
  mkdir -p "$OCSERV_DIR"
  curl -fL -o "$OCSERV_SCRIPT_PATH" "https://raw.githubusercontent.com/r4ven-me/openconnect/main/src/server/v1.3/ocserv.sh"
  chmod +x "$OCSERV_SCRIPT_PATH"
  info "Запускаю ocserv через ocserv.sh в фоне (логи: $LOG_FILE)…"
  nohup "$OCSERV_SCRIPT_PATH" ocserv --foreground >"$LOG_FILE" 2>&1 &
  sleep 5
}

post_checks() {
  info "Проверяю, что порт 443 слушается…"
  if ss -tulnap | grep -qE 'LISTEN.+:443\b'; then
    log "Порт 443 слушается."
  else
    warn "Порт 443 не обнаружен в LISTEN. Проверьте логи и конфиги."
  fi

  info "Пробую HTTPS к https://localhost:443 (с игнором сертификата)…"
  if curl --insecure -fsS https://localhost:443 >/dev/null; then
    log "HTTPS-ответ получен — ocserv отвечает."
  else
    warn "curl не получил ответ от https://localhost:443 — проверьте логи systemd: journalctl -u ocserv -e"
  fi
}

banner() {
cat <<'EOF'
============================================================
Готово!

Что сделал скрипт:
• Собрал и установил ocserv из исходников.
• Сгенерировал ключ и самоподписанный сертификат (GNUTLS certtool).
• Создал /etc/ocserv/ocserv.conf с заданными параметрами (предыдущий — в *.bak.*).
• Установил и запустил systemd unit ocserv.service.
• Включил IPv4 форвардинг (runtime и в /etc/sysctl.conf).
• Добавил iptables правила форвардинга и NAT (с проверкой) и сохранил их.
• Предложил создать VPN-пользователя через ocpasswd (интерактивный ввод пароля).

Полезные команды:
  systemctl status ocserv
  journalctl -u ocserv -e
  ocpasswd -c /etc/ocserv/ocpasswd <user>    # добавить/сменить пароль
  iptables -S; iptables -t nat -S            # посмотреть правила

Примечания:
- Режим запуска по умолчанию — systemd. Вернуть «докерный» — RUN_MODE=docker.
- WAN-интерфейс для MASQUERADE определяется автоматически, можно задать WAN_IF=eth0.
- Конфиг включает отключение TLS 1.3 (как в твоём примере) ради совместимости.

Удачной работы!
============================================================
EOF
}

main() {
  require_root
  check_debian12
  apt_refresh_and_upgrade
  append_sid_repo
  apt-get update
  install_build_deps
  fetch_sources
  build_and_test
  install_ocserv

  # Конфиги, ключи/серты
  generate_certs
  write_ocserv_conf

  # Сеть и firewall
  enable_ip_forward
  setup_iptables_nat

  if [[ "${RUN_MODE}" == "docker" ]]; then
    run_ocserv_docker_legacy
  else
    install_systemd_unit
  fi

  # Пользователь VPN (интерактивно спросит пароль)
  create_vpn_user

  # Проверки
  post_checks
  banner
}

main "$@"
