import { Box, Card } from "@vkontakte/vkui";
import YouTube from "react-youtube";

import styles from "./Brainrot.module.css";

interface BrainrotProps {
  videoId: string;
}

export const Brainrot = ({ videoId }: BrainrotProps) => {
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
