#!/bin/bash

> /tmp/vpnator-outline.log  # Initialize log file

set -e; . /etc/os-release; if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then echo "Error: This script only supports Ubuntu and Debian" >&2 && exit 1; fi
if ! command -v sudo &> /dev/null; then if [ "$EUID" -eq 0 ]; then apt update >> /tmp/vpnator-outline.log 2>&1 && apt install -y sudo >> /tmp/vpnator-outline.log 2>&1; else echo "Error: sudo is not installed and script is not running as root. Please run as root to install sudo." >&2 && exit 1; fi; fi
# VPNATOR-STATUS-REPORT Обновление пакетов...

sudo apt update 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null

# VPNATOR-STATUS-REPORT Пакеты обновлены
# VPNATOR-STATUS-REPORT Настройка Docker...

set -e; . /etc/os-release; if ! command -v docker &> /dev/null; then sudo apt install -y ca-certificates curl gnupg lsb-release 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; if [ ! -f /etc/apt/keyrings/docker.gpg ]; then sudo install -m 0755 -d /etc/apt/keyrings 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; curl -fsSL https://download.docker.com/linux/${ID}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; sudo chmod a+r /etc/apt/keyrings/docker.gpg; fi; if command -v lsb_release &> /dev/null; then DIST_CODENAME=$(lsb_release -cs); else DIST_CODENAME=${VERSION_CODENAME}; fi; if [ -f /etc/apt/sources.list.d/docker.list ]; then if ! grep -q "download.docker.com/linux/${ID}" /etc/apt/sources.list.d/docker.list; then sudo rm -f /etc/apt/sources.list.d/docker.list 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; fi; fi; DOCKER_ARCH=$(dpkg --print-architecture); if [ ! -f /etc/apt/sources.list.d/docker.list ]; then echo "deb [arch=${DOCKER_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list | sudo tee -a /tmp/vpnator-outline.log > /dev/null; fi; sudo apt update 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; fi

sudo systemctl enable docker 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; sudo systemctl start docker 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null

# VPNATOR-STATUS-REPORT Docker настроен
# VPNATOR-STATUS-REPORT Установка Outline Server...

set -e; if sudo docker ps -a --format '{{.Names}}' | grep -q 'shadowbox\|watchtower'; then sudo docker ps -a --filter "name=shadowbox" --filter "name=watchtower" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; if ! sudo docker ps --format '{{.Names}}' | grep -q 'shadowbox'; then sudo docker start shadowbox 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null || echo "Failed to start shadowbox" >&2; fi; if ! sudo docker ps --format '{{.Names}}' | grep -q 'watchtower'; then sudo docker start watchtower 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null || echo "Failed to start watchtower" >&2; fi; else sudo mkdir -p /opt/outline; wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-server/master/src/server_manager/install_scripts/install_server.sh | sudo bash 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; fi
if ! sudo test -f /opt/outline/access.txt; then echo "Error: Outline server access file not found at /opt/outline/access.txt" >&2 && exit 1; fi

# VPNATOR-STATUS-REPORT Outline Server установлен
# VPNATOR-STATUS-REPORT Генерация нового ключа...

sudo grep "^apiUrl:" /opt/outline/access.txt | sed 's/^apiUrl://' | tr -d '[:space:]' | sudo tee /tmp/api_url | sudo tee -a /tmp/vpnator-outline.log > /dev/null
if [ -z "$(cat /tmp/api_url)" ]; then echo "Error: Could not extract apiUrl from /opt/outline/access.txt" >&2 && exit 1; fi
if ! command -v jq &> /dev/null; then sudo apt install -y jq 2>&1 | sudo tee -a /tmp/vpnator-outline.log > /dev/null; fi
if [ -z "$(curl -s -k "$(cat /tmp/api_url)/access-keys" 2>> /tmp/vpnator-outline.log)" ] || ! curl -s -k "$(cat /tmp/api_url)/access-keys" 2>> /tmp/vpnator-outline.log | jq -e '.accessKeys | length > 0' >> /tmp/vpnator-outline.log 2>&1; then NEW_KEY=$(curl -s -k -X POST "$(cat /tmp/api_url)/access-keys" 2>> /tmp/vpnator-outline.log); if [ -z "$NEW_KEY" ]; then echo "Error: Failed to create new access key (empty response)" >&2 && exit 1; fi; if echo "$NEW_KEY" | jq -e '.error' >> /tmp/vpnator-outline.log 2>&1; then ERROR_MSG=$(echo "$NEW_KEY" | jq -r '.error // "Unknown error"' 2>> /tmp/vpnator-outline.log); echo "Error: Failed to create new access key - $ERROR_MSG" >&2 && echo "API response: $NEW_KEY" >&2 && exit 1; fi; fi
curl -s -k "$(cat /tmp/api_url)/access-keys" 2>> /tmp/vpnator-outline.log | jq -r '.accessKeys[0].accessUrl // empty' 2>> /tmp/vpnator-outline.log | sudo tee /tmp/user_access_key | sudo tee -a /tmp/vpnator-outline.log > /dev/null
if [ -z "$(cat /tmp/user_access_key)" ] || [ "$(cat /tmp/user_access_key)" = "null" ] || [ "$(cat /tmp/user_access_key)" = "" ]; then echo "Error: Could not extract accessUrl from API response" >&2 && exit 1; fi

# VPNATOR-STATUS-REPORT Ключ сохранен в outline-key.txt

cat /tmp/user_access_key # VPNATOR-SAVE-OUTPUT
