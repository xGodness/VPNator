import {
  AppRoot,
  Panel,
  PanelHeader,
  Root,
  Spacing,
  SplitCol,
  SplitLayout,
  usePlatform,
  View,
} from "@vkontakte/vkui";
import { useEffect, useState } from "react";

import { SettingsForm } from "./ui/SettingsForm/SettingsForm";
import { useWebSocket } from "./modules/webSocket/useWebSocket";
import { ServerMessages } from "./ui/ServerMessages/ServerMessages";
import { ServerConfig } from "./modules/serverConfig/serverConfig.types";

const vpnProtocols = [
  {
    value: "outline",
    label: "Outline",
  },
  {
    value: "openconnect",
    label: "OpenConnect",
  },
  {
    value: "xray",
    label: "XRay",
  },
];

const WEBSOCKETS_URL = import.meta.env.VITE_WS_URL;

const enum MessageType {
  info = "info",
  end = "end",
}
interface ParsedMessage {
  type: MessageType;
  text: string;
}

const parseMessage = (message: string): ParsedMessage => {
  if (message === "VPNATOR-COMPLETE") {
    return {
      type: MessageType.end,
      text: "Настройка завершена",
    };
  }

  return {
    type: MessageType.info,
    text: message,
  };
};

export default function App() {
  const platform = usePlatform();

  const [isOpened, setIsOpened] = useState(true);
  useEffect(() => {
    if (!isOpened) close();
  }, [isOpened]);

  const [messages, setMessages] = useState<string[]>([]);
  const onmessage = ({ data }: MessageEvent<string>) => {
    const { type, text } = parseMessage(data);

    if (type === MessageType.end) {
      setIsOpened(false);
      setInProgress(false);
    }

    setMessages((prevMessages) => [...prevMessages, text]);
  };

  const { send, close } = useWebSocket({ url: WEBSOCKETS_URL, onmessage });

  const [inProgress, setInProgress] = useState(false);
  const onSettingsFormSubmit = (config: ServerConfig) => {
    const { username, password, protocol, remoteAddress } = config;
    setInProgress(true);
    send(`install ${protocol} ${remoteAddress} ${username} ${password}`);
  };
  const onCancel = () => {
    // send('cancel');
    setInProgress(false);
  };

  return (
    <AppRoot disableSettingVKUIClassesInRuntime>
      <SplitLayout
        header={platform !== "vkcom" && <PanelHeader delimiter="none" />}
      >
        <SplitCol stretchedOnMobile autoSpaced>
          <Root activeView="form-view">
            <View id="form-view" activePanel="form-panel">
              <Panel id="form-panel">
                <PanelHeader>VPNator</PanelHeader>
                <SettingsForm
                  vpnProtocols={vpnProtocols}
                  onSubmit={onSettingsFormSubmit}
                  inProgress={inProgress}
                  onCancel={onCancel}
                />
                <Spacing size="m" />
                {messages.length > 0 && <ServerMessages messages={messages} />}
              </Panel>
            </View>
          </Root>
        </SplitCol>
      </SplitLayout>
    </AppRoot>
  );
}
