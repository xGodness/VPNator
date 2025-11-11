import { Box, Card } from "@vkontakte/vkui";

interface ServerMessagesProps {
  messages: string[];
}

export const ServerMessages = ({ messages }: ServerMessagesProps) => {
  return (
    <Card mode="shadow">
      {messages.map((message) => (
        <Box>{message}</Box>
      ))}
    </Card>
  );
};
