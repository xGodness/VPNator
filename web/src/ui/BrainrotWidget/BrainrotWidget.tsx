import { Box, Button, Card, Flex } from "@vkontakte/vkui";
import YouTube from "react-youtube";

import styles from "./BrainrotWidget.module.css";
import { useState } from "react";

interface BrainrotWidgetProps {
  videoId: string;
}

export const BrainrotWidget = ({ videoId }: BrainrotWidgetProps) => {
  const [showBrainrot, setShowBrainrot] = useState(false);

  if (!showBrainrot) {
    return (
      <Flex justify="center" align="center" style={{ height: "390px" }}>
        <Button size="m" onClick={() => setShowBrainrot(true)}>
          У меня СДВГ
        </Button>
      </Flex>
    );
  }

  return (
    <Box>
      <YouTube
        className={styles.root}
        videoId={videoId}
        opts={{ height: "390", playerVars: { autoplay: 1 } }}
      />
    </Box>
  );
};
