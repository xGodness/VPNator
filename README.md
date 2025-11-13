# VPNator

## VPNator web

### Настройка и запуск

Перед первым запуском нужно настроить окружение

```bash
./setup.sh
```

Ссылка на WebSocket должна лежать в переменной окружения VITE_WS_URL

```bash
VITE_WS_URL="wss://echo.websocket.org"
```

Запуск локального дев-сервера

```bash
npm run dev
```
