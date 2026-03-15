import { Composition } from "remotion";
import { EchoelPromo } from "./EchoelPromo";
import { FeatureShowcase } from "./FeatureShowcase";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="EchoelPromo"
        component={EchoelPromo}
        durationInFrames={300}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{
          tagline: "Bio-Reactive Creative Performance",
          features: [
            "Real-time Bio-Signal Processing at 120Hz",
            "12 Creative Tools — Zero Dependencies",
            "HRV → Music → Visuals → Light",
          ],
        }}
      />
      <Composition
        id="FeatureShowcase"
        component={FeatureShowcase}
        durationInFrames={450}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          feature: "EchoelSynth",
          description: "DDSP synthesis driven by your heartbeat",
        }}
      />
    </>
  );
};
