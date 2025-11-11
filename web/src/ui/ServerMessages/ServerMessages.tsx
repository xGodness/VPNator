import { Box, Card, Flex, Text, Title } from "@vkontakte/vkui";

import styles from "./ServerMessages.module.css";

interface ServerMessagesProps {
  messages: string[];
}

const Message = ({ text }: { text: string }) => {
  return (
    <Card mode="outline-tint">
      <Box padding="m">
        <Text className={styles.message}>{text}</Text>
      </Box>
    </Card>
  );
};

export const ServerMessages = ({ messages }: ServerMessagesProps) => {
  return (
    <Card mode="shadow">
      <Box padding="m">
        <Title level="2">Ход выполнения</Title>
      </Box>
      <Box padding="m">
        <Flex direction="column" gap="m">
          {messages.map((message) => (
            <Message key={message} text={message} />
          ))}
        </Flex>
      </Box>
    </Card>
  );
};
