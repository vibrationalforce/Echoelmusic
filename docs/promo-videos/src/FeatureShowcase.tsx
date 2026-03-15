import React from "react";
import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  useVideoConfig,
  spring,
  Sequence,
} from "remotion";

const BRAND = {
  bg: "#0A0A0C",
  surface: "#141418",
  accent: "#3B82F6",
  text: "#F5F5F7",
  textSecondary: "#8E8E93",
  green: "#30D158",
};

const TOOLS = [
  { name: "EchoelSynth", icon: "waveform", desc: "DDSP bio-reactive synthesis" },
  { name: "EchoelMix", icon: "slider.horizontal.3", desc: "Console, metering, BPM sync" },
  { name: "EchoelFX", icon: "wand.and.stars", desc: "20+ effects, Neve/SSL emulation" },
  { name: "EchoelSeq", icon: "square.grid.3x3", desc: "Step sequencer, patterns" },
  { name: "EchoelMIDI", icon: "pianokeys", desc: "MIDI 2.0, MPE, touch instruments" },
  { name: "EchoelBio", icon: "heart.text.square", desc: "HRV, HR, breathing, ARKit" },
  { name: "EchoelVis", icon: "eye", desc: "8 modes, Metal 120fps" },
  { name: "EchoelVid", icon: "video", desc: "Capture, edit, stream, ProRes" },
  { name: "EchoelLux", icon: "lightbulb", desc: "DMX 512, Art-Net, lasers" },
  { name: "EchoelStage", icon: "display", desc: "External displays, AirPlay" },
  { name: "EchoelNet", icon: "network", desc: "Ableton Link, Dante, <10ms" },
  { name: "EchoelAI", icon: "brain", desc: "CoreML, LLM, stem separation" },
];

interface Props {
  feature: string;
  description: string;
}

export const FeatureShowcase: React.FC<Props> = ({ feature, description }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  return (
    <AbsoluteFill style={{ backgroundColor: BRAND.bg, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      {/* Header */}
      <Sequence from={0} durationInFrames={90}>
        <div
          style={{
            position: "absolute",
            top: 120,
            left: 0,
            right: 0,
            textAlign: "center",
          }}
        >
          <div
            style={{
              opacity: spring({ frame, fps, durationInFrames: 20 }),
              fontSize: 18,
              color: BRAND.accent,
              letterSpacing: "0.1em",
              textTransform: "uppercase",
              marginBottom: 16,
            }}
          >
            12 EchoelTools
          </div>
          <div
            style={{
              opacity: spring({ frame: frame - 10, fps, durationInFrames: 20 }),
              fontSize: 48,
              fontWeight: 700,
              color: BRAND.text,
              letterSpacing: "-0.02em",
            }}
          >
            One Platform
          </div>
        </div>
      </Sequence>

      {/* Tool grid */}
      <Sequence from={45} durationInFrames={durationInFrames - 45}>
        <div
          style={{
            position: "absolute",
            top: 300,
            left: 48,
            right: 48,
            display: "flex",
            flexWrap: "wrap",
            gap: 16,
            justifyContent: "center",
          }}
        >
          {TOOLS.map((tool, i) => {
            const toolFrame = frame - 45 - i * 8;
            const opacity = spring({
              frame: toolFrame,
              fps,
              durationInFrames: 15,
            });
            const scale = interpolate(opacity, [0, 1], [0.9, 1]);
            const isHighlighted = tool.name === feature;

            return (
              <div
                key={tool.name}
                style={{
                  opacity,
                  transform: `scale(${scale})`,
                  width: 220,
                  padding: "20px 16px",
                  background: isHighlighted ? `${BRAND.accent}15` : BRAND.surface,
                  border: `1px solid ${isHighlighted ? BRAND.accent : BRAND.surface}`,
                  borderRadius: 12,
                  textAlign: "center",
                }}
              >
                <div
                  style={{
                    fontSize: 20,
                    fontWeight: 600,
                    color: isHighlighted ? BRAND.accent : BRAND.text,
                    marginBottom: 6,
                  }}
                >
                  {tool.name}
                </div>
                <div
                  style={{
                    fontSize: 13,
                    color: BRAND.textSecondary,
                    lineHeight: 1.4,
                  }}
                >
                  {tool.desc}
                </div>
              </div>
            );
          })}
        </div>
      </Sequence>

      {/* Bottom tagline */}
      <Sequence from={200} durationInFrames={250}>
        <div
          style={{
            position: "absolute",
            bottom: 140,
            left: 0,
            right: 0,
            textAlign: "center",
            opacity: spring({
              frame: frame - 200,
              fps,
              durationInFrames: 20,
            }),
          }}
        >
          <div style={{ fontSize: 24, color: BRAND.green, fontWeight: 600 }}>
            Zero Dependencies
          </div>
          <div style={{ fontSize: 16, color: BRAND.textSecondary, marginTop: 8 }}>
            100% Native — AVFoundation + Accelerate + Metal
          </div>
        </div>
      </Sequence>
    </AbsoluteFill>
  );
};
