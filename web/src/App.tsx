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
import { useState } from "react";

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

export default function App() {
  const platform = usePlatform();

  const [messages, setMessages] = useState<string[]>([]);
  const onmessage = ({ data }: MessageEvent<string>) => {
    setMessages((prevMessages) => [...prevMessages, data]);
  };

  const { send } = useWebSocket({ url: WEBSOCKETS_URL, onmessage });

  const onSettingsFormSubmit = (config: ServerConfig) => {
    const { username, password, protocol, remoteAddress } = config;
    send(`install ${protocol} ${remoteAddress} ${username} ${password}`);
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
