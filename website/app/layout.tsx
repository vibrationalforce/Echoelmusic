import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Echoelmusic - Transform Your Heartbeat Into Music",
    template: "%s | Echoelmusic",
  },
  description: "Professional DAW plugin with biofeedback sensors. 46 DSP effects, ultra-low latency, multi-platform support. Available for Windows, macOS, Linux, and iOS.",
  keywords: [
    "echoelmusic",
    "biofeedback",
    "music production",
    "DAW plugin",
    "VST3",
    "Audio Units",
    "DSP effects",
    "heart rate variability",
    "HRV",
    "audio plugin",
    "music software",
    "@echoelmusic",
  ],
  authors: [{ name: "Echoelmusic" }],
  creator: "Echoelmusic",
  publisher: "Echoelmusic",
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://echoelmusic.com",
    title: "Echoelmusic - Transform Your Heartbeat Into Music",
    description: "Professional DAW plugin with biofeedback sensors. 46 DSP effects, ultra-low latency, multi-platform support.",
    siteName: "Echoelmusic",
    images: [
      {
        url: "/og-image.jpg",
        width: 1200,
        height: 630,
        alt: "Echoelmusic - Biofeedback Music Production",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    site: "@echoelmusic",
    creator: "@echoelmusic",
    title: "Echoelmusic - Transform Your Heartbeat Into Music",
    description: "Professional DAW plugin with biofeedback sensors. 46 DSP effects, ultra-low latency.",
    images: ["/og-image.jpg"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  icons: {
    icon: "/favicon.ico",
    shortcut: "/favicon-16x16.png",
    apple: "/apple-touch-icon.png",
  },
  manifest: "/site.webmanifest",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=IBM+Plex+Mono:wght@400;600&family=VT323&display=swap" rel="stylesheet" />

        {/* Schema.org JSON-LD */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@type": "SoftwareApplication",
              "name": "Echoelmusic",
              "applicationCategory": "MultimediaApplication",
              "operatingSystem": "Windows 10+, macOS 10.13+, Linux, iOS 15+",
              "offers": {
                "@type": "Offer",
                "price": "0",
                "priceCurrency": "USD",
              },
              "aggregateRating": {
                "@type": "AggregateRating",
                "ratingValue": "4.8",
                "ratingCount": "1024",
              },
              "author": {
                "@type": "Organization",
                "name": "Echoelmusic",
              },
              "description": "Professional DAW plugin with biofeedback sensors featuring 46 DSP effects and ultra-low latency audio processing.",
            }),
          }}
        />
      </head>
      <body className="bg-dark text-white font-sans antialiased">
        {children}
      </body>
    </html>
  );
}
