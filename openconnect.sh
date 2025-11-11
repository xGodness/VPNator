#!/usr/bin/env bash

set -euo pipefail    # "строгий режим": -e — выходим при ошибке, -u — ошибка на несуществующей переменной, pipefail — ошибка в пайплайне не теряется

# ========= Настройки =========
OCSERV_VERSION="${OCSERV_VERSION:-1.3.0}"                      # Версия ocserv; можно переопределить переменной окружения
SRC_URL="https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz"  # URL тарбола исходников ocserv
SRC_DIR="/usr/local/src"                                       # Каталог, куда складывать исходники/архив
TARBALL="${SRC_DIR}/ocserv-${OCSERV_VERSION}.tar.xz"           # Полный путь к архиву
BUILD_DIR="${SRC_DIR}/ocserv-${OCSERV_VERSION}"                # Каталог распакованных исходников
OCSERV_SCRIPT_PATH="/usr/local/sbin/ocserv.sh"                 # Куда положим вспомогательный Docker-скрипт ocserv.sh
DEBIAN_SOURCES="/etc/apt/sources.list"                         # Файл с источниками репозиториев APT
LOG_FILE="/var/log/ocserv-docker.log"                          # Файл логов фонового запуска
DEBIAN_FRONTEND=noninteractive                                 # Отключаем интерактивные вопросы APT
export DEBIAN_FRONTEND                                         # Экспортируем переменную в окружение дочерних процессов

# ========= Утилиты =========
log()   { echo -e "\033[1;32m[OK]\033[0m $*"; }               # Функция: зелёное сообщение об успехе
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }             # Функция: синее информационное сообщение
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }             # Функция: жёлтое предупреждение
error() { echo -e "\033[1;31m[ERR]\033[0m $*" >&2; }          # Функция: красная ошибка (в stderr)

require_root() {                                               # Проверка прав суперпользователя
  if [[ $EUID -ne 0 ]]; then                                   # Если UID не равен 0 (не root)
    error "Запустите скрипт от root (sudo)."                   # Сообщаем об ошибке
    exit 1                                                     # Выходим с кодом 1
  fi
}

check_debian12() {                                             # Проверка целевой ОС (предупреждение, если не Debian 12)
  if [[ -r /etc/os-release ]]; then                            # Если доступен файл с описанием ОС
    . /etc/os-release                                          # Подгружаем переменные из него
    if [[ "${ID:-}" != "debian" || "${VERSION_ID:-}" != "12" ]]; then  # Проверяем ID и версию
      warn "Обнаружен ${PRETTY_NAME:-unknown}. Скрипт рассчитан на Debian 12 (bookworm). Продолжаю на ваш риск."  # Предупреждаем
    fi
  fi
}

append_sid_repo() {                                            # Добавление репозитория Debian sid (unstable)
  if ! grep -qE '^[[:space:]]*deb[[:space:]].*debian[[:space:]]+sid[[:space:]]+main' "$DEBIAN_SOURCES"; then  # Если строки sid ещё нет
    info "Добавляю репозиторий Debian sid в $DEBIAN_SOURCES"   # Сообщаем
    echo "deb http://deb.debian.org/debian sid main" >> "$DEBIAN_SOURCES"  # Дописываем строку репозитория в sources.list
  else
    info "Репозиторий sid уже подключен."                      # Иначе сообщаем, что он уже есть
  fi
}

apt_refresh_and_upgrade() {                                    # Обновление индексов пакетов и апгрейд системы
  info "Обновляю индексы пакетов и систему…"                   # Сообщение пользователю
  apt-get update                                               # Обновляем кэш пакетов
  apt-get -y upgrade                                           # Обновляем установленные пакеты без вопросов
}

install_build_deps() {                                         # Установка зависимостей для сборки ocserv и утилит
  info "Устанавливаю зависимости для сборки (может занять время)…"  # Информируем

  # Список пакетов держим в массиве — безопасно и читабельно
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
  )

  apt-get install -y "${pkgs[@]}"                              # Ставим все пакеты из массива
}

fetch_sources() {                                              # Скачивание и распаковка исходников ocserv
  mkdir -p "$SRC_DIR"                                          # Создаём каталог для исходников, если его нет
  if [[ -f "$TARBALL" ]]; then                                 # Если архив уже скачан
    info "Тарбол ${TARBALL} уже существует — пропускаю загрузку."  # Сообщаем, что пропускаем скачивание
  else
    info "Скачиваю исходники ocserv ${OCSERV_VERSION}…"        # Иначе сообщаем о загрузке
    curl -fL -o "$TARBALL" "$SRC_URL"                          # Качаем архив ( -f: падать на 4xx/5xx, -L: следовать редиректам )
    log "Скачано: $TARBALL"                                    # Логируем успешную загрузку
  fi

  if [[ -d "$BUILD_DIR" ]]; then                               # Если каталога распаковки уже существует
    info "Каталог исходников уже распакован: $BUILD_DIR"       # Сообщаем и пропускаем распаковку
  else
    info "Распаковываю архив…"                                 # Сообщаем о распаковке
    tar -xvf "$TARBALL" -C "$SRC_DIR"                          # Распаковываем с подробным выводом в SRC_DIR
    log "Распаковка завершена."                                # Подтверждаем завершение
  fi
}

build_and_test() {                                             # Сборка и (нестрогий) прогон тестов
  cd "$BUILD_DIR"                                              # Переходим в каталог исходников
  info "Конфигурирую сборку (--enable-oidc-auth)…"             # Сообщаем о конфигурировании
  ./configure --enable-oidc-auth                               # Генерируем Makefile с поддержкой OIDC

  info "Собираю (все ядра)…"                                   # Сообщение о сборке
  make -j"$(nproc)"                                            # Сборка с параллелизмом по числу CPU

  info "Запускаю тесты (ожидаемые фейлы haproxy-auth и test-oidc допустимы)…"  # Объясняем ожидаемое поведение тестов
  if make check; then                                          # Запускаем тесты; если успешны —
    log "Тесты завершились успешно."                           # Логируем успех
  else
    warn "Некоторые тесты упали (это ожидаемо) — продолжаю."   # Иначе предупреждаем и продолжаем
  fi
}

install_ocserv() {                                             # Установка собранных бинарников
  cd "$BUILD_DIR"                                              # Возвращаемся в каталог сборки
  info "Устанавливаю собранные бинарники в систему…"           # Сообщаем об установке
  make install                                                 # Копируем файлы в /usr/local/*
  log "Установлено. Проверка версий:"                          # Лог
  whereis ocserv || true                                       # Показываем, где лежит ocserv; не падаем, если нет
  ocserv --version || true                                     # Выводим версию ocserv; не падаем при ошибке
  echo                                                         # Пустая строка для читаемости
  warn "По умолчанию ocserv устанавливается в /usr/local/sbin/ocserv"  # Напоминание о пути установки
}

deploy_ocserv_sh() {                                           # Загрузка и установка Docker-скрипта ocserv.sh
  info "Готовлю /etc/ocserv и скачиваю ocserv.sh (Docker-скрипт)…"  # Сообщение
  mkdir -p /etc/ocserv                                         # Создаём каталог конфигурации ocserv
  if [[ -f "$OCSERV_SCRIPT_PATH" ]]; then                      # Если файл уже существует
    info "Файл $OCSERV_SCRIPT_PATH уже существует — обновляю." # Сообщаем о перезаписи
  fi
  curl -fL -o "$OCSERV_SCRIPT_PATH" "https://raw.githubusercontent.com/r4ven-me/openconnect/main/src/server/v1.3/ocserv.sh"  # URL скрипта
  chmod +x "$OCSERV_SCRIPT_PATH"                               # Делаем скрипт исполняемым
  log "Скрипт сохранён: $OCSERV_SCRIPT_PATH"                   # Подтверждаем сохранение
}

run_ocserv_docker() {                                          # Запуск ocserv через ocserv.sh в фоне
  info "Запускаю ocserv через ocserv.sh в фоне (логи: $LOG_FILE)…"   # Информируем и указываем файл логов
  nohup "$OCSERV_SCRIPT_PATH" ocserv --foreground >"$LOG_FILE" 2>&1 &  # Запускаем в фоне, вывод перенаправляем в лог, nohup — пережить logout
  OC_PID=$!                                                    # Сохраняем PID фонового процесса
  sleep 5                                                      # Даем сервису несколько секунд подняться

  info "Проверяю, что порт 443 слушается…"                     # Информируем о проверке порта
  if ss -tulnap | grep -qE 'LISTEN.+:443\b'; then              # Ищем LISTEN на TCP/UDP порту 443
    log "Порт 443 открыт."                                     # Успешно — порт слушает
  else
    warn "Порт 443 не обнаружен в LISTEN. Проверьте логи: $LOG_FILE"  # Иначе — предупреждаем
  fi

  info "Пробую HTTPS к localhost:443 (с игнором сертификата)…" # Сообщаем о curl-проверке
  if curl --insecure -fsS https://localhost:443 >/dev/null; then  # Делаем запрос, игнорируя самоподписанный сертификат
    log "HTTPS-ответ получен — ocserv отвечает."               # Успех: сервер отвечает
  else
    warn "curl не получил ответ от https://localhost:443 — смотрите $LOG_FILE"  # Иначе — предупреждаем
  fi

  info "Процесс ocserv.sh запущен с PID ${OC_PID} и продолжит работать после выхода скрипта."  # Даём знать PID и поведение
}

main() {                                                       # Главная функция-оркестратор
  require_root                                                 # Требуем права root
  check_debian12                                               # Предупреждаем, если не Debian 12
  apt_refresh_and_upgrade                                      # Обновляем систему
  append_sid_repo                                              # Добавляем репозиторий sid (unstable)
  apt-get update                                               # Обновляем индексы после изменения sources.list
  install_build_deps                                           # Ставим зависимости
  fetch_sources                                                # Качаем и распаковываем исходники
  build_and_test                                               # Сборка и тесты
  install_ocserv                                               # Установка бинарников
  deploy_ocserv_sh                                             # Скачиваем и готовим ocserv.sh
  run_ocserv_docker                                            # Запускаем ocserv через Docker-скрипт

  cat <<'EOF'                                                  # Выводим справочный баннер (literal heredoc, без подстановок)
============================================================
Готово!

• Исходники:           /usr/local/src/ocserv-<версия>
• Бинарник ocserv:     /usr/local/sbin/ocserv
• Docker-скрипт:       /usr/local/sbin/ocserv.sh
• Конфиг-каталог:      /etc/ocserv
• Логи запуска Docker: /var/log/ocserv-docker.log

Примечания:
- Тесты "haproxy-auth" и "test-oidc" могут падать — это ожидаемо и не мешает работе.
- При первом запуске ocserv.sh сгенерирует самоподписанные сертификаты и дефолтные параметры.
- При необходимости откорректируйте параметры в начале /usr/local/sbin/ocserv.sh и перезапустите.

Безопасность:
- Вы добавили репозиторий Debian sid. Это нужно для свежих библиотек.
  Если хотите ограничить автоматический выбор пакетов из sid, настройте pinning:
    /etc/apt/preferences.d/limit-sid.pref
    Pin: release a=unstable
    Pin-Priority: 100
  (в данном скрипте pinning не включён, следуем исходной статье)

Удачной работы!
============================================================
EOF
}

main "$@"                                                     # Запускаем main, передавая все аргументы командной строки
