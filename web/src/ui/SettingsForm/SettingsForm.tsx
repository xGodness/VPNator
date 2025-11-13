import {
  Box,
  Button,
  ButtonGroup,
  Card,
  Flex,
  FormItem,
  FormLayoutGroup,
  IconButton,
  Input,
  Select,
  Title,
  Tooltip,
} from "@vkontakte/vkui";
import { ChangeEvent, useCallback, useEffect, useState } from "react";
import { SelectValue } from "@vkontakte/vkui/dist/components/NativeSelect/NativeSelect";

import { useFormField } from "../../utils/useFormField";
import {
  ServerConfig,
  VpnProtocol,
} from "../../modules/serverConfig/serverConfig.types";

import styles from "./SettingsForm.module.css";
import { Icon16InfoOutline } from "@vkontakte/icons";

interface SettingsFormProps {
  vpnProtocols: { value: string; label: string }[];
  onSubmit?: (config: ServerConfig) => void;
  inProgress: boolean;
  onCancel?: () => void;
}

export const SettingsForm = ({
  vpnProtocols,
  onSubmit,
  inProgress,
  onCancel,
}: SettingsFormProps) => {
  const [username, onUsernameChange] = useFormField("");
  const [password, onPasswordChange] = useFormField("");
  const [remoteAddress, onRemoteAddressChange] = useFormField("");

  const [vpnUsername, onVpnUsernameChange, setVpnUsername] = useFormField("");
  const [vpnPassword, onVpnPasswordChange, setVpnPassword] = useFormField("");

  const [protocol, setProtocol] = useState(VpnProtocol.outline);
  useEffect(() => {
    if (protocol !== VpnProtocol.openconnect) {
      setVpnUsername("");
      setVpnPassword("");
    }
  }, [protocol]);

  const onProtocolChange = useCallback(
    (_: ChangeEvent<HTMLSelectElement>, newValue: SelectValue) => {
      setProtocol(newValue as VpnProtocol);
    },
    [setProtocol]
  );

  const onSubmitButton = () => {
    onSubmit?.({
      username,
      password,
      protocol,
      remoteAddress,
      vpnUsername,
      vpnPassword,
    });
  };

  return (
    <Box>
      <Box padding="2xl">
        <Title level="2">Настройка конфига</Title>
      </Box>
      <Flex className={styles.form} direction="column">
        <FormLayoutGroup mode="vertical">
          <FormItem htmlFor="protocol" top="Протокол">
            <Select
              options={vpnProtocols}
              value={protocol}
              onChange={onProtocolChange}
              name="protocol"
              id="protocol"
            />
          </FormItem>
          <FormItem htmlFor="address" top="Адрес">
            <Input
              name="address"
              id="address"
              value={remoteAddress}
              onChange={onRemoteAddressChange}
              after={
                <Tooltip
                  placement="top"
                  description="Укажите адрес удаленного сервера. Опционально можете указать порт через двоеточие"
                >
                  <Icon16InfoOutline />
                </Tooltip>
              }
            />
          </FormItem>
          <FormLayoutGroup mode="horizontal">
            <FormItem htmlFor="username" top="Имя пользователя">
              <Input
                name="username"
                id="username"
                value={username}
                onChange={onUsernameChange}
                after={
                  <Tooltip
                    placement="top"
                    description="Имя пользователя для подключения к удаленному серверу по ssh"
                  >
                    <Icon16InfoOutline />
                  </Tooltip>
                }
              />
            </FormItem>
            <FormItem htmlFor="password" top="Пароль">
              <Input
                name="password"
                id="password"
                type="password"
                value={password}
                onChange={onPasswordChange}
              />
            </FormItem>
          </FormLayoutGroup>
          {protocol === VpnProtocol.openconnect && (
            <FormLayoutGroup mode="horizontal">
              <FormItem
                htmlFor="vpn-username"
                top="Имя пользователя OpenConnect"
              >
                <Input
                  name="vpn-username"
                  id="vpn-username"
                  value={vpnUsername}
                  onChange={onVpnUsernameChange}
                  after={
                    <Tooltip
                      placement="top"
                      description="Укажите имя пользователя для протокола"
                    >
                      <Icon16InfoOutline />
                    </Tooltip>
                  }
                />
              </FormItem>
              <FormItem htmlFor="vpn-password" top="Пароль OpenConnect">
                <Input
                  name="vpn-password"
                  id="vpn-password"
                  type="password"
                  value={vpnPassword}
                  onChange={onVpnPasswordChange}
                />
              </FormItem>
            </FormLayoutGroup>
          )}
        </FormLayoutGroup>
        <Box padding="2xl">
          <ButtonGroup>
            <Button
              type="submit"
              size="m"
              onClick={onSubmitButton}
              loading={inProgress}
            >
              Настроить
            </Button>
            {inProgress && (
              <Button size="m" onClick={onCancel} mode="outline">
                Отмена
              </Button>
            )}
          </ButtonGroup>
        </Box>
      </Flex>
    </Box>
  );
};
