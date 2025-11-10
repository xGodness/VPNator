#!/usr/bin/env bash  # Запускаем скрипт под bash через env для кроссплатформенности путей

set -euo pipefail      # Строгий режим: -e — выход при ошибке, -u — ошибка при обращении к несуществующей переменной, pipefail — учитывать ошибки в пайпах

# ============ Параметры сборки ============ 
OCSERV_VERSION="${OCSERV_VERSION:-1.3.0}"                               # Версия исходников ocserv; можно переопределить переменной окружения
OPENCONNECT_TAG="${OPENCONNECT_TAG:-v1.3}"                               # Тег Docker-образов (builder и финального)
WORKDIR="${WORKDIR:-$HOME/ocserv}"                                       # Рабочая директория, куда будем скачивать файлы и вести сборку
DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}"                                  # Включаем BuildKit для ускорения/кеша сборки

# ============ Имена образов ============ 
BUILDER_IMAGE="openconnect-build:${OPENCONNECT_TAG}"                      # Имя и тег образа-сборщика
FINAL_IMAGE="openconnect:${OPENCONNECT_TAG}"                              # Имя и тег финального образа

# ============ Ссылки на исходники (GitHub raw) ============ 
URL_BASE="https://raw.githubusercontent.com/r4ven-me/openconnect/main/src/server/v1.3"  # Базовый URL для файлов из репозитория
URL_BUILD_DF="${URL_BASE}/Dockerfile_build"                               # Ссылка на Dockerfile сборщика
URL_FINAL_DF="${URL_BASE}/Dockerfile"                                     # Ссылка на финальный Dockerfile (многостадийный)
URL_OCSERV_SH="${URL_BASE}/ocserv.sh"                                     # Ссылка на скрипт запуска ocserv внутри контейнера
URL_COMPOSE_YML="${URL_BASE}/docker-compose.yml"                          # Ссылка на docker-compose.yml
URL_ENV_FILE="${URL_BASE}/.env"                                           # Ссылка на пример .env

# ============ Имена файлов в WORKDIR ============ 
FILE_BUILD_DF="Dockerfile_build"                                          # Локальное имя Dockerfile сборщика
FILE_FINAL_DF="Dockerfile"                                                # Локальное имя финального Dockerfile
FILE_OCSERV_SH="ocserv.sh"                                                # Локальное имя скрипта запуска
FILE_COMPOSE_YML="docker-compose.yml"                                     # Локальное имя compose-файла
FILE_ENV=".env"                                                           # Локальное имя .env

# ============ Разноцветные сообщения ============ 
log()   { echo -e "\033[1;32m[OK]\033[0m $*"; }                           # Зелёный маркер для успеха
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }                         # Синий маркер для информации
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }                         # Жёлтый маркер для предупреждений
error() { echo -e "\033[1;31m[ERR]\033[0m $*" >&2; }                      # Красный маркер для ошибок (в stderr)

# ============ Проверки окружения ============ 
require_cmd() { command -v "$1" >/dev/null 2>&1; }                        # Универсальная проверка наличия команды в PATH

pick_compose() {                                                           # Определяем, чем запускать Compose: плагином 'docker compose' или бинарём 'docker-compose'
  if docker compose version >/dev/null 2>&1; then                          # Пробуем встроенный плагин Docker
    echo "docker compose"                                                  # Если ок — используем 'docker compose'
  elif require_cmd docker-compose; then                                    # Иначе — классический отдельный бинарь
    echo "docker-compose"                                                  # Возвращаем 'docker-compose'
  else
    echo ""                                                                # Не найдено — вернём пустую строку
  fi
}

require_docker() {                                                         # Проверяем наличие и работоспособность Docker Engine
  if ! require_cmd docker; then                                            # Если нет команды docker
    error "Docker не найден. Установите Docker Engine и повторите запуск." # Сообщаем о необходимости установки
    exit 1                                                                 # Прерываем скрипт
  fi
  if ! docker info >/dev/null 2>&1; then                                   # Проверяем доступ к демону (не root, группа docker и т.п.)
    error "Нет доступа к Docker (docker info). Запустите с нужными правами (root или в группе docker)."  # Подсказка по правам
    exit 1                                                                 # Выходим
  fi
}

# ============ Подготовка файлов ============ 
ensure_workdir() {                                                         # Создаём/проверяем рабочую директорию
  mkdir -p "$WORKDIR"                                                      # Создаём каталог, если его нет
  cd "$WORKDIR"                                                            # Переходим в рабочую директорию
  info "Рабочая директория: $WORKDIR"                                      # Сообщаем, где будем работать
}

fetch_file() {                                                             # Универсальная функция скачивания файла, если он отсутствует
  local url="$1"                                                           # Аргумент 1 — URL
  local path="$2"                                                          # Аргумент 2 — путь назначения
  if [[ -f "$path" ]]; then                                                # Если файл уже есть
    info "Файл $path уже существует — пропускаю скачивание."               # Сообщаем о пропуске
  else
    info "Скачиваю: $url → $path"                                          # Сообщаем о загрузке
    curl -fL -o "$path" "$url"                                             # Качаем ( -f: падаем на 4xx/5xx; -L: следуем редиректам )
    log "Скачан файл: $path"                                               # Подтверждаем скачивание
  fi
}

# ============ Сборка образов ============ 
build_builder_image() {                                                    # Сборка образа-сборщика из Dockerfile_build
  info "Собираю образ сборщика: ${BUILDER_IMAGE}"                          # Сообщаем имя/тег образа
  DOCKER_BUILDKIT="$DOCKER_BUILDKIT" docker build \                        # Запускаем docker build с учётом BuildKit
    -f "$FILE_BUILD_DF" \                                                  # Указываем файл Dockerfile сборщика
    ./ \                                                                   # Контекстом сборки делаем текущую директорию
    -t "$BUILDER_IMAGE"                                                    # Тегируем результирующий образ
  log "Собран образ: $BUILDER_IMAGE"                                       # Подтверждаем сборку
}

build_final_image() {                                                      # Сборка финального компактного образа из многостадийного Dockerfile
  info "Собираю финальный образ: ${FINAL_IMAGE}"                           # Сообщаем имя/тег финального образа
  chmod +x "$FILE_OCSERV_SH"                                               # На всякий случай — делаем скрипт запуска исполняемым (он копируется в образ)
  DOCKER_BUILDKIT="$DOCKER_BUILDKIT" docker build \                        # Запускаем docker build
    -f "$FILE_FINAL_DF" \                                                  # Указываем финальный Dockerfile (в нём FROM builder + COPY)
    ./ \                                                                   # Контекст сборки — текущая директория
    -t "$FINAL_IMAGE"                                                      # Тегируем финальный образ
  log "Собран образ: $FINAL_IMAGE"                                         # Подтверждаем сборку
}

show_images() {                                                            # Выводим короткий список образов openconnect*
  info "Образы openconnect* в локальном реестре:"                          # Комментарий к выводу
  docker image ls | grep -E 'openconnect(-build)?:' || true                # Фильтруем список образов по маске; не падаем, если ничего не найдено
}

# ============ Docker Compose: загрузка и запуск ============ 
prepare_compose() {                                                        # Готовим файлы docker-compose и .env
  fetch_file "$URL_COMPOSE_YML" "$FILE_COMPOSE_YML"                        # Скачиваем docker-compose.yml (если нет)
  fetch_file "$URL_ENV_FILE" "$FILE_ENV"                                   # Скачиваем .env (если нет) — его можно отредактировать под себя
}

compose_up() {                                                             # Поднимаем сервис через Compose
  local compose_bin                                                         # Локальная переменная под команду Compose
  compose_bin="$(pick_compose)"                                            # Определяем доступную команду Compose
  if [[ -z "$compose_bin" ]]; then                                         # Если Compose не найден
    warn "Docker Compose не найден. Вы можете запустить вручную позже: 'docker compose up -d' (или установить compose)."  # Сообщаем, что пропускаем авто-подъём
    return 0                                                               # Выходим из функции без ошибки
  fi
  info "Запускаю сервис через ${compose_bin}…"                             # Сообщаем, чем будем поднимать
  ${compose_bin} up -d                                                     # Запускаем контейнеры в фоне (detached)
  log "Сервис запущен. Проверьте статус: ${compose_bin} ps"                # Подтверждаем запуск и предлагаем команду проверки
}

# ============ Быстрый smoke-тест без Compose (опционально) ============ 
smoke_run_optional() {                                                     # Небольшой запуск контейнера без Compose — на ваш риск/по умолчанию пропускаем
  if [[ "${SMOKE_RUN:-0}" != "1" ]]; then                                  # По умолчанию не запускаем; включается переменной SMOKE_RUN=1
    info "SMOKE_RUN=1 не задан — пропускаю одиночный docker run (рекомендуется использовать Compose)." # Сообщаем о пропуске
    return 0                                                               # Выходим
  fi
  info "Выполняю пробный запуск контейнера без Compose…"                   # Информируем о пробном запуске
  docker run --rm -d --name ocserv-test "$FINAL_IMAGE" >/dev/null         # Запускаем контейнер в фоне, удаляем после остановки
  sleep 3                                                                  # Даём несколько секунд на старт
  docker ps | grep ocserv-test || warn "Контейнер ocserv-test не найден в 'docker ps' — проверьте логи." # Проверяем, запустился ли контейнер
  docker stop ocserv-test >/dev/null || true                               # Останавливаем тестовый контейнер
  log "Пробный запуск завершён."                                           # Подтверждаем завершение
}

# ============ Главный сценарий ============ 
main() {                                                                   # Точка входа в скрипт
  require_docker                                                           # Проверяем наличие Docker и доступ к демону
  ensure_workdir                                                           # Готовим рабочую директорию

  fetch_file "$URL_BUILD_DF" "$FILE_BUILD_DF"                              # Скачиваем Dockerfile_build
  build_builder_image                                                      # Собираем образ-сборщик

  fetch_file "$URL_FINAL_DF" "$FILE_FINAL_DF"                              # Скачиваем финальный Dockerfile
  fetch_file "$URL_OCSERV_SH" "$FILE_OCSERV_SH"                            # Скачиваем скрипт запуска ocserv.sh
  build_final_image                                                        # Собираем финальный образ

  show_images                                                              # Показываем собранные образы

  prepare_compose                                                          # Скачиваем docker-compose.yml и .env
  compose_up                                                               # Поднимаем сервис через Compose (если установлен)

  smoke_run_optional                                                       # (Опционально) выполнить одиночный docker run, если SMOKE_RUN=1

  cat <<'EOF'                                                              # Поясняющий баннер по результатам работы
============================================================
Готово!

Что сделано:
• Собран образ сборки: openconnect-build:v1.3
• Собран финальный образ: openconnect:v1.3
• Скачаны docker-compose.yml и .env в рабочую папку

Дальше:
• Отредактируйте при необходимости файл .env в папке сборки.
• Если Compose не был запущен, поднимите сервис вручную:
    docker compose up -d
  (или 'docker-compose up -d' — смотря что установлено)

Полезные команды:
• Список образов:        docker image ls | grep openconnect
• Статус контейнеров:    docker compose ps
• Логи сервиса:          docker compose logs -f
============================================================
EOF                                                                       # Закрываем heredoc баннер
}

main "$@"                                                                  # Запускаем основной сценарий, передавая аргументы командной строки
