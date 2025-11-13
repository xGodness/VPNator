# VPNator

## Презентация
[Ссылка](https://docs.google.com/presentation/d/1M-hD7ZeMmfPStacPce1kXTsUimI97tKj/edit?usp=sharing&ouid=101911802605495571084&rtpof=true&sd=true)

## VPNator server

### Требования

python версии не ниже 13

### Запуск исполняемого файла

Для MacOS исполняемый файл находится по адресу `backend/dist/vpnator_server`. \
Для остальных ОС аналогичные файлы появятся позже (либо вы можете сбилдить их самостоятельно).

### Самостоятельная сборка
```bash
make build
```

### Поднятие без сборки
```bash
make backend
```

## VPNator web


### Настройка и запуск

Перед первым запуском нужно настроить окружение

```bash
./setup.sh
```

Ссылка на WebSocket должна лежать в переменной окружения `VITE_WS_URL` (можно завести `web/.env`)

```
VITE_WS_URL=ws://127.0.0.1:8000/ws
```

Запуск локального дев-сервера

```bash
npm run dev
```
