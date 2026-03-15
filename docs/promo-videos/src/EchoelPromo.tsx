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
  coral: "#FF6B6B",
};

interface Props {
  tagline: string;
  features: string[];
}

const CoherenceWave: React.FC<{ frame: number; fps: number }> = ({
  frame,
  fps,
}) => {
  const points: string[] = [];
  const width = 1920;
  const height = 200;
  const centerY = height / 2;

  for (let x = 0; x <= width; x += 4) {
    const t = frame / fps;
    const coherence = interpolate(frame, [0, 150, 300], [0.2, 0.9, 0.6], {
      extrapolateRight: "clamp",
    });
    const amplitude = coherence * 80;
    const frequency = 0.008 + coherence * 0.004;
    const y =
      centerY +
      Math.sin(x * frequency + t * 2) * amplitude +
      Math.sin(x * frequency * 2.3 + t * 1.5) * amplitude * 0.3;
    points.push(`${x},${y}`);
  }

  return (
    <svg
      width={width}
      height={height}
      style={{ position: "absolute", bottom: 80, left: 0, opacity: 0.6 }}
    >
      <polyline
        points={points.join(" ")}
        fill="none"
        stroke={BRAND.accent}
        strokeWidth="2"
      />
      <polyline
        points={points.join(" ")}
        fill="none"
        stroke={BRAND.green}
        strokeWidth="1"
        strokeDasharray="4,8"
        opacity="0.5"
      />
    </svg>
  );
};

const BioMetric: React.FC<{
  label: string;
  value: string;
  unit: string;
  frame: number;
  fps: number;
  delay: number;
}> = ({ label, value, unit, frame, fps, delay }) => {
  const opacity = spring({ frame: frame - delay, fps, durationInFrames: 20 });
  const translateY = interpolate(opacity, [0, 1], [20, 0]);

  return (
    <div
      style={{
        opacity,
        transform: `translateY(${translateY}px)`,
        textAlign: "center",
        padding: "0 32px",
      }}
    >
      <div
        style={{
          fontSize: 14,
          color: BRAND.textSecondary,
          letterSpacing: "0.05em",
          textTransform: "uppercase",
          marginBottom: 4,
        }}
      >
        {label}
      </div>
      <div style={{ fontSize: 48, fontWeight: 700, color: BRAND.text }}>
        {value}
        <span
          style={{
            fontSize: 18,
            color: BRAND.textSecondary,
            marginLeft: 4,
          }}
        >
          {unit}
        </span>
      </div>
    </div>
  );
};

export const EchoelPromo: React.FC<Props> = ({ tagline, features }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleOpacity = spring({ frame, fps, durationInFrames: 30 });
  const titleScale = interpolate(titleOpacity, [0, 1], [0.95, 1]);

  return (
    <AbsoluteFill style={{ backgroundColor: BRAND.bg, fontFamily: "system-ui, -apple-system, sans-serif" }}>
      {/* Bio coherence wave background */}
      <CoherenceWave frame={frame} fps={fps} />

      {/* Title */}
      <Sequence from={0} durationInFrames={120}>
        <AbsoluteFill
          style={{
            justifyContent: "center",
            alignItems: "center",
            opacity: titleOpacity,
            transform: `scale(${titleScale})`,
          }}
        >
          <div
            style={{
              fontSize: 72,
              fontWeight: 700,
              color: BRAND.text,
              letterSpacing: "-0.02em",
            }}
          >
            Echoelmusic
          </div>
          <div
            style={{
              fontSize: 24,
              color: BRAND.accent,
              marginTop: 16,
              letterSpacing: "0.05em",
            }}
          >
            {tagline}
          </div>
        </AbsoluteFill>
      </Sequence>

      {/* Bio metrics */}
      <Sequence from={60} durationInFrames={180}>
        <div
          style={{
            position: "absolute",
            top: 120,
            left: 0,
            right: 0,
            display: "flex",
            justifyContent: "center",
            gap: 80,
          }}
        >
          <BioMetric label="Heart Rate" value="72" unit="bpm" frame={frame - 60} fps={fps} delay={0} />
          <BioMetric label="HRV" value="0.82" unit="" frame={frame - 60} fps={fps} delay={10} />
          <BioMetric label="Coherence" value="0.91" unit="" frame={frame - 60} fps={fps} delay={20} />
          <BioMetric label="Breath" value="12" unit="/min" frame={frame - 60} fps={fps} delay={30} />
        </div>
      </Sequence>

      {/* Features */}
      <Sequence from={120} durationInFrames={180}>
        <div
          style={{
            position: "absolute",
            bottom: 320,
            left: 0,
            right: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            gap: 24,
          }}
        >
          {features.map((feat, i) => {
            const featureOpacity = spring({
              frame: frame - 120 - i * 15,
              fps,
              durationInFrames: 20,
            });
            return (
              <div
                key={feat}
                style={{
                  opacity: featureOpacity,
                  fontSize: 28,
                  color: BRAND.text,
                  padding: "12px 32px",
                  background: BRAND.surface,
                  borderRadius: 8,
                  border: `1px solid ${BRAND.accent}22`,
                }}
              >
                {feat}
              </div>
            );
          })}
        </div>
      </Sequence>

      {/* App Store badge area */}
      <Sequence from={240} durationInFrames={60}>
        <div
          style={{
            position: "absolute",
            bottom: 40,
            left: 0,
            right: 0,
            textAlign: "center",
          }}
        >
          <div
            style={{
              opacity: spring({ frame: frame - 240, fps, durationInFrames: 20 }),
              fontSize: 20,
              color: BRAND.textSecondary,
            }}
          >
            Available on the App Store
          </div>
        </div>
      </Sequence>
    </AbsoluteFill>
  );
};
