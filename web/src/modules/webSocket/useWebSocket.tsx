import { useEffect, useRef, useState } from "react";

import { noop } from "../../utils/noop";

interface WebSocketValue {
  send: WebSocket["send"];
  close: WebSocket["close"];
  open: (url: string | URL) => void;
}

interface WebSocketParams<T = any> {
  onopen?: (event: Event) => void;
  onmessage?: (event: MessageEvent<T>) => void;
  onclose?: (event: CloseEvent) => void;
  onerror?: (event: Event) => void;
}

export const useWebSocket = <T extends unknown>({
  onopen = noop,
  onmessage = noop,
  onclose = noop,
  onerror = noop,
}: WebSocketParams<T>): WebSocketValue => {
  const [webSocket, setWebSocket] = useState<WebSocket | null>(null);
  const webSocketRef = useRef<WebSocket | null>(null);

  const messagesQueueRef = useRef<
    (string | ArrayBufferLike | Blob | ArrayBufferView<ArrayBufferLike>)[]
  >([]);
  const sendToQueue: WebSocket["send"] = (message) => {
    messagesQueueRef.current.push(message);
  };

  const open = (url: string | URL) => {
    // Close existing WebSocket if any
    if (webSocketRef.current) {
      const ws = webSocketRef.current;
      ws.onclose = noop; // Prevent calling onclose when we manually close
      ws.onerror = noop; // Prevent calling onerror when we manually close
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        ws.close();
      }
      webSocketRef.current = null;
      setWebSocket(null);
    }

    const ws = new WebSocket(url);
    webSocketRef.current = ws;

    ws.onopen = (event: Event) => {
      setWebSocket(ws);
      onopen(event);

      while (messagesQueueRef.current.length > 0) {
        const msg = messagesQueueRef.current[0];
        messagesQueueRef.current.splice(0, 1);
        ws.send(msg);
      }
    };

    ws.onmessage = onmessage;
    ws.onclose = (event: CloseEvent) => {
      webSocketRef.current = null;
      setWebSocket(null);
      onclose(event);
    };
    ws.onerror = onerror;
  };

  const close = () => {
    if (webSocketRef.current) {
      const ws = webSocketRef.current;
      ws.onclose = noop; // Prevent calling onclose when we manually close
      ws.onerror = noop; // Prevent calling onerror when we manually close
      if (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING) {
        ws.close();
      }
      webSocketRef.current = null;
      setWebSocket(null);
    }
  };

  return {
    open,
    send: webSocket?.send.bind(webSocket) ?? sendToQueue,
    close,
  };
};

