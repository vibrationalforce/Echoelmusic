"use client";

import { motion } from "framer-motion";
import Link from "next/link";

export default function Home() {
  return (
    <main className="min-h-screen">
      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center justify-center px-4 overflow-hidden">
        {/* Animated background */}
        <div className="absolute inset-0 vaporwave-bg opacity-30" />

        {/* Grid pattern overlay */}
        <div className="absolute inset-0 bg-[linear-gradient(to_right,#00E5FF15_1px,transparent_1px),linear-gradient(to_bottom,#00E5FF15_1px,transparent_1px)] bg-[size:4rem_4rem]" />

        <div className="relative z-10 max-w-6xl mx-auto text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
          >
            <h1 className="text-6xl md:text-8xl font-display mb-6 gradient-text">
              ECHOELMUSIC
            </h1>
            <p className="text-2xl md:text-4xl mb-4 text-gray-300">
              Transform Your Heartbeat Into Music
            </p>
            <p className="text-lg md:text-xl mb-12 text-gray-400 max-w-3xl mx-auto">
              Professional DAW plugin with biofeedback sensors • 46 DSP Effects • Ultra-Low Latency • Multi-Platform
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Link href="/download">
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="px-8 py-4 bg-gradient-to-r from-primary to-secondary rounded-lg font-semibold text-lg glow-box"
                >
                  Download Free
                </motion.button>
              </Link>

              <Link href="https://github.com/vibrationalforce/Echoelmusic">
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="px-8 py-4 border-2 border-primary rounded-lg font-semibold text-lg hover:bg-primary hover:text-dark transition-colors"
                >
                  View Source Code
                </motion.button>
              </Link>
            </div>

            {/* Platforms */}
            <div className="mt-12 text-sm text-gray-400">
              Available for: Windows • macOS • Linux • iOS
            </div>
          </motion.div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 px-4">
        <div className="max-w-7xl mx-auto">
          <motion.h2
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            className="text-4xl md:text-5xl font-bold text-center mb-16 gradient-text"
          >
            Features
          </motion.h2>

          <div className="grid md:grid-cols-3 gap-8">
            {features.map((feature, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.1 }}
                className="p-6 bg-dark-lighter rounded-lg glow-box border border-primary/20"
              >
                <div className="text-4xl mb-4">{feature.icon}</div>
                <h3 className="text-2xl font-semibold mb-3 text-primary">{feature.title}</h3>
                <p className="text-gray-300 mb-4">{feature.description}</p>
                <ul className="text-sm text-gray-400 space-y-1">
                  {feature.details.map((detail, i) => (
                    <li key={i}>• {detail}</li>
                  ))}
                </ul>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="py-20 px-4 vaporwave-bg">
        <div className="max-w-6xl mx-auto">
          <div className="grid md:grid-cols-4 gap-8 text-center">
            {stats.map((stat, index) => (
              <motion.div
                key={index}
                initial={{ opacity: 0, scale: 0.9 }}
                whileInView={{ opacity: 1, scale: 1 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.1 }}
              >
                <div className="text-5xl font-bold gradient-text mb-2">{stat.value}</div>
                <div className="text-gray-400">{stat.label}</div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Tech Specs Section */}
      <section className="py-20 px-4">
        <div className="max-w-6xl mx-auto">
          <motion.h2
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            className="text-4xl md:text-5xl font-bold text-center mb-16 gradient-text"
          >
            Technical Specifications
          </motion.h2>

          <div className="grid md:grid-cols-2 gap-12">
            <div>
              <h3 className="text-2xl font-semibold mb-6 text-primary">Plugin Formats</h3>
              <ul className="space-y-3 text-gray-300">
                <li>✅ VST3 (Windows, macOS, Linux)</li>
                <li>✅ Audio Units (macOS)</li>
                <li>✅ AUv3 (iOS)</li>
                <li>✅ CLAP (Modern DAWs)</li>
                <li>✅ Standalone Application</li>
              </ul>
            </div>

            <div>
              <h3 className="text-2xl font-semibold mb-6 text-primary">Performance</h3>
              <ul className="space-y-3 text-gray-300">
                <li>⚡ Ultra-low latency (&lt;1ms capable)</li>
                <li>🚀 SIMD optimizations (AVX2/NEON/SSE)</li>
                <li>🔧 Link-Time Optimization (LTO)</li>
                <li>💾 Memory-efficient (4-5 MB binary)</li>
                <li>⚙️ Multi-threaded audio processing</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4">
        <div className="max-w-4xl mx-auto text-center">
          <motion.div
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
          >
            <h2 className="text-4xl md:text-5xl font-bold mb-6 gradient-text">
              Ready to Transform Your Music?
            </h2>
            <p className="text-xl text-gray-300 mb-8">
              Download Echoelmusic today and experience the future of biofeedback music production.
            </p>
            <Link href="/download">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="px-12 py-5 bg-gradient-to-r from-primary to-secondary rounded-lg font-semibold text-xl glow-box"
              >
                Download Now - Free
              </motion.button>
            </Link>
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-4 border-t border-gray-800">
        <div className="max-w-6xl mx-auto text-center text-gray-400">
          <div className="flex justify-center gap-8 mb-6">
            <Link href="https://github.com/vibrationalforce/Echoelmusic" className="hover:text-primary transition-colors">
              GitHub
            </Link>
            <Link href="https://twitter.com/echoelmusic" className="hover:text-primary transition-colors">
              Twitter
            </Link>
            <Link href="https://instagram.com/echoelmusic" className="hover:text-primary transition-colors">
              Instagram
            </Link>
          </div>
          <p>© 2025 Echoelmusic. All rights reserved.</p>
          <p className="mt-2 text-sm">
            Open Source • Multi-Platform • Professional Audio Processing
          </p>
        </div>
      </footer>
    </main>
  );
}

const features = [
  {
    icon: "🎛️",
    title: "46 DSP Effects",
    description: "Professional audio processing suite",
    details: [
      "Dynamics: Compressors, Limiters",
      "EQ: Parametric, Passive, Dynamic",
      "Modulation: Chorus, Flanger, Phaser",
      "Reverb: Shimmer, Convolution",
      "Mastering: AI-powered, Style-aware",
    ],
  },
  {
    icon: "❤️",
    title: "Biofeedback",
    description: "Transform your physiology into sound",
    details: [
      "Heart Rate Variability (HRV)",
      "Coherence monitoring",
      "Real-time bio-reactive DSP",
      "Health-focused audio features",
      "Resonance healing modes",
    ],
  },
  {
    icon: "🎵",
    title: "MIDI Tools",
    description: "Intelligent composition assistance",
    details: [
      "ChordGenius: Smart chord progressions",
      "MelodyForge: AI melody generation",
      "BasslineArchitect: Groove creation",
      "ArpWeaver: Advanced arpeggiator",
      "World Music Database: Global scales",
    ],
  },
  {
    icon: "⚡",
    title: "Ultra-Low Latency",
    description: "Optimized for real-time performance",
    details: [
      "Under 1ms latency achievable",
      "SIMD optimizations (AVX2/NEON)",
      "Multi-threaded processing",
      "Lock-free audio threading",
      "Adaptive buffer sizing",
    ],
  },
  {
    icon: "💻",
    title: "Multi-Platform",
    description: "Works everywhere you do",
    details: [
      "Windows 10+ (WASAPI, ASIO)",
      "macOS 10.13+ (Universal Binary)",
      "Linux (ALSA, JACK)",
      "iOS 15+ (AUv3)",
      "Consistent UX across platforms",
    ],
  },
  {
    icon: "🎨",
    title: "Modern UI",
    description: "Beautiful vaporwave aesthetic",
    details: [
      "OpenGL-accelerated graphics",
      "Real-time spectrum analyzer",
      "Customizable color schemes",
      "Touch-optimized (iOS)",
      "Retina/4K ready",
    ],
  },
];

const stats = [
  { value: "46+", label: "DSP Effects" },
  { value: "<1ms", label: "Latency" },
  { value: "4.8★", label: "Rating" },
  { value: "5", label: "Platforms" },
];
