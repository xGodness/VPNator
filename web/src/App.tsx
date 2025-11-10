import {
  AppRoot,
  Box,
  Button,
  Card,
  Div,
  Flex,
  FormItem,
  FormLayoutGroup,
  Input,
  Panel,
  PanelHeader,
  Root,
  Select,
  SplitCol,
  SplitLayout,
  Title,
  usePlatform,
  View,
} from "@vkontakte/vkui";

import styles from "./App.module.css";

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

export default function App() {
  const platform = usePlatform();

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
                <Card mode="shadow">
                  <Box padding="2xl">
                    <Title level="2">Настройка конфига</Title>
                  </Box>
                  <Flex className={styles.form} direction="column">
                    <FormLayoutGroup mode="vertical">
                      <FormItem htmlFor="address" top="Адрес">
                        <Input name="address" id="address" />
                      </FormItem>
                      <FormItem htmlFor="protocol" top="Протокол">
                        <Select
                          options={vpnProtocols}
                          defaultValue={null}
                          name="protocol"
                          id="protocol"
                        />
                      </FormItem>
                      <FormLayoutGroup mode="horizontal">
                        <FormItem htmlFor="username" top="Имя пользователя">
                          <Input name="username" id="username" />
                        </FormItem>
                        <FormItem htmlFor="password" top="Пароль">
                          <Input
                            name="password"
                            id="password"
                            type="password"
                          />
                        </FormItem>
                      </FormLayoutGroup>
                    </FormLayoutGroup>
                    <Box padding="2xl">
                      <Button type="submit" size="m">
                        Настроить
                      </Button>
                    </Box>
                  </Flex>
                </Card>
              </Panel>
            </View>
          </Root>
        </SplitCol>
      </SplitLayout>
    </AppRoot>
  );
}
