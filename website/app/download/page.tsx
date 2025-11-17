"use client";

import { motion } from "framer-motion";
import Link from "next/link";

export default function Download() {
  return (
    <main className="min-h-screen py-20 px-4">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-center mb-16"
        >
          <h1 className="text-5xl md:text-6xl font-bold mb-6 gradient-text">
            Download Echoelmusic
          </h1>
          <p className="text-xl text-gray-300 max-w-3xl mx-auto">
            Choose your platform and start creating biofeedback music today.
            All versions are free and open source.
          </p>
        </motion.div>

        {/* Download Cards */}
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6 mb-16">
          {platforms.map((platform, index) => (
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
              className="p-6 bg-dark-lighter rounded-lg glow-box border border-primary/20 hover:border-primary/50 transition-colors"
            >
              <div className="text-6xl mb-4 text-center">{platform.icon}</div>
              <h3 className="text-2xl font-semibold mb-2 text-center text-primary">
                {platform.name}
              </h3>
              <p className="text-gray-400 text-center mb-4 text-sm">
                {platform.version}
              </p>

              <ul className="text-sm text-gray-300 space-y-2 mb-6">
                {platform.features.map((feature, i) => (
                  <li key={i}>✓ {feature}</li>
                ))}
              </ul>

              <Link href={platform.downloadLink}>
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="w-full py-3 bg-gradient-to-r from-primary to-secondary rounded-lg font-semibold"
                >
                  Download
                </motion.button>
              </Link>

              <p className="text-xs text-gray-500 text-center mt-3">
                {platform.size}
              </p>
            </motion.div>
          ))}
        </div>

        {/* Installation Instructions */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="mb-16"
        >
          <h2 className="text-3xl font-bold mb-8 text-center gradient-text">
            Installation Instructions
          </h2>

          <div className="grid md:grid-cols-3 gap-8">
            {instructions.map((instruction, index) => (
              <div key={index} className="p-6 bg-dark-lighter rounded-lg border border-primary/20">
                <h3 className="text-xl font-semibold mb-4 text-primary">
                  {instruction.platform}
                </h3>
                <ol className="space-y-3 text-gray-300 text-sm">
                  {instruction.steps.map((step, i) => (
                    <li key={i}>
                      <span className="font-semibold text-primary">{i + 1}.</span> {step}
                    </li>
                  ))}
                </ol>
              </div>
            ))}
          </div>
        </motion.div>

        {/* System Requirements */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="mb-16"
        >
          <h2 className="text-3xl font-bold mb-8 text-center gradient-text">
            System Requirements
          </h2>

          <div className="grid md:grid-cols-2 gap-8">
            <div className="p-6 bg-dark-lighter rounded-lg border border-primary/20">
              <h3 className="text-xl font-semibold mb-4 text-primary">Minimum</h3>
              <ul className="space-y-2 text-gray-300">
                <li>• CPU: Dual-core 2.0 GHz</li>
                <li>• RAM: 4 GB</li>
                <li>• Storage: 100 MB free space</li>
                <li>• Audio: ASIO/CoreAudio/ALSA compatible</li>
                <li>• Display: 1280x720</li>
              </ul>
            </div>

            <div className="p-6 bg-dark-lighter rounded-lg border border-primary/20">
              <h3 className="text-xl font-semibold mb-4 text-primary">Recommended</h3>
              <ul className="space-y-2 text-gray-300">
                <li>• CPU: Quad-core 3.0 GHz (AVX2 support)</li>
                <li>• RAM: 8 GB or more</li>
                <li>• Storage: 500 MB free space</li>
                <li>• Audio: Dedicated audio interface</li>
                <li>• Display: 1920x1080 or higher</li>
              </ul>
            </div>
          </div>
        </motion.div>

        {/* Support */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold mb-6 gradient-text">Need Help?</h2>
          <p className="text-gray-300 mb-6">
            Check our documentation or open an issue on GitHub
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link href="https://github.com/vibrationalforce/Echoelmusic">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="px-8 py-3 border-2 border-primary rounded-lg font-semibold hover:bg-primary hover:text-dark transition-colors"
              >
                Documentation
              </motion.button>
            </Link>
            <Link href="https://github.com/vibrationalforce/Echoelmusic/issues">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="px-8 py-3 border-2 border-secondary rounded-lg font-semibold hover:bg-secondary hover:text-dark transition-colors"
              >
                Report Issue
              </motion.button>
            </Link>
          </div>
        </motion.div>

        {/* Back to home */}
        <div className="mt-12 text-center">
          <Link href="/" className="text-primary hover:text-secondary transition-colors">
            ← Back to Home
          </Link>
        </div>
      </div>
    </main>
  );
}

const platforms = [
  {
    icon: "🐧",
    name: "Linux",
    version: "Ubuntu 20.04+, Arch, Fedora",
    features: [
      "VST3 Plugin",
      "Standalone App",
      "ALSA/JACK support",
      "x86_64 architecture",
    ],
    downloadLink: "https://github.com/vibrationalforce/Echoelmusic/releases/latest",
    size: "4.4 MB",
  },
  {
    icon: "🪟",
    name: "Windows",
    version: "Windows 10/11 (64-bit)",
    features: [
      "VST3 Plugin",
      "Standalone App",
      "WASAPI/ASIO support",
      "Installer included",
    ],
    downloadLink: "https://github.com/vibrationalforce/Echoelmusic/releases/latest",
    size: "5.1 MB",
  },
  {
    icon: "🍎",
    name: "macOS",
    version: "macOS 10.13+ (Universal)",
    features: [
      "VST3 Plugin",
      "Audio Units (AU)",
      "Standalone App",
      "Apple Silicon + Intel",
    ],
    downloadLink: "https://github.com/vibrationalforce/Echoelmusic/releases/latest",
    size: "10.5 MB",
  },
  {
    icon: "📱",
    name: "iOS",
    version: "iOS 15+ (iPad)",
    features: [
      "AUv3 Plugin",
      "Standalone App",
      "Touch-optimized UI",
      "HealthKit integration",
    ],
    downloadLink: "https://apps.apple.com/app/echoelmusic",
    size: "8.2 MB",
  },
];

const instructions = [
  {
    platform: "Windows",
    steps: [
      "Download Echoelmusic-Windows-x86_64.zip",
      "Extract the archive",
      "Run the installer or copy VST3 folder",
      "VST3: Copy to C:\\Program Files\\Common Files\\VST3\\",
      "Rescan plugins in your DAW",
    ],
  },
  {
    platform: "macOS",
    steps: [
      "Download Echoelmusic-macOS-Universal.dmg",
      "Open the DMG file",
      "Drag Echoelmusic.app to Applications",
      "VST3: Copy to ~/Library/Audio/Plug-Ins/VST3/",
      "AU: Copy to ~/Library/Audio/Plug-Ins/Components/",
    ],
  },
  {
    platform: "Linux",
    steps: [
      "Download Echoelmusic-Linux-x86_64.tar.gz",
      "Extract: tar -xzf Echoelmusic-Linux-x86_64.tar.gz",
      "VST3: cp -r *.vst3 ~/.vst3/",
      "Standalone: sudo cp Echoelmusic /usr/local/bin/",
      "Rescan plugins in your DAW",
    ],
  },
];
