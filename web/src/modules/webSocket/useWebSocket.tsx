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

  const messagesQueueRef = useRef<
    (string | ArrayBufferLike | Blob | ArrayBufferView<ArrayBufferLike>)[]
  >([]);
  const sendToQueue: WebSocket["send"] = (message) => {
    messagesQueueRef.current.push(message);
  };

  const open = (url: string | URL) => {
    const ws = new WebSocket(url);

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
    ws.onclose = onclose;
    ws.onerror = onerror;
  };

  return {
    open,
    send: webSocket?.send.bind(webSocket) ?? sendToQueue,
    close: webSocket?.close.bind(webSocket) ?? noop,
  };
};
