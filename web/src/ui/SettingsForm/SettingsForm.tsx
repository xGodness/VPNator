import {
  Box,
  Button,
  Card,
  Flex,
  FormItem,
  FormLayoutGroup,
  Input,
  Select,
  Title,
} from "@vkontakte/vkui";
import { ChangeEvent, useCallback, useState } from "react";
import { SelectValue } from "@vkontakte/vkui/dist/components/NativeSelect/NativeSelect";

import { useFormField } from "../../utils/useFormField";
import {
  ServerConfig,
  VpnProtocol,
} from "../../modules/serverConfig/serverConfig.types";

import styles from "./SettingsForm.module.css";

interface SettingsFormProps {
  vpnProtocols: { value: string; label: string }[];
  onSubmit?: (config: ServerConfig) => void;
}

export const SettingsForm = ({ vpnProtocols, onSubmit }: SettingsFormProps) => {
  const [username, onUsernameChange] = useFormField("");
  const [password, onPasswordChange] = useFormField("");
  const [remoteAddress, onRemoteAddressChange] = useFormField("");

  const [protocol, setProtocol] = useState(VpnProtocol.outline);
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
    });
  };

  return (
    <Card mode="shadow">
      <Box padding="2xl">
        <Title level="2">Настройка конфига</Title>
      </Box>
      <Flex className={styles.form} direction="column">
        <FormLayoutGroup mode="vertical">
          <FormItem htmlFor="address" top="Адрес">
            <Input
              name="address"
              id="address"
              value={remoteAddress}
              onChange={onRemoteAddressChange}
            />
          </FormItem>
          <FormItem htmlFor="protocol" top="Протокол">
            <Select
              options={vpnProtocols}
              value={protocol}
              onChange={onProtocolChange}
              name="protocol"
              id="protocol"
            />
          </FormItem>
          <FormLayoutGroup mode="horizontal">
            <FormItem htmlFor="username" top="Имя пользователя">
              <Input
                name="username"
                id="username"
                value={username}
                onChange={onUsernameChange}
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
        </FormLayoutGroup>
        <Box padding="2xl">
          <Button type="submit" size="m" onClick={onSubmitButton}>
            Настроить
          </Button>
        </Box>
      </Flex>
    </Card>
  );
};
