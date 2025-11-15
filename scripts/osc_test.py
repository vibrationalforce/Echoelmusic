#!/usr/bin/env python3
"""
OSC Test Script for Echoelmusic
Tests bidirectional OSC communication between iOS and Desktop

Requirements:
    pip install python-osc

Usage:
    # Test as iOS (send biofeedback to Desktop)
    python osc_test.py --mode ios --desktop-ip 192.168.1.100

    # Test as Desktop (receive from iOS, send analysis back)
    python osc_test.py --mode desktop --ios-ip 192.168.1.50

    # Interactive mode (both sender and receiver)
    python osc_test.py --mode interactive
"""

import argparse
import time
import math
from pythonosc import udp_client, dispatcher, osc_server
from pythonosc.osc_message_builder import OscMessageBuilder
import threading

# OSC Ports
DESKTOP_PORT = 8000
IOS_PORT = 8001

# Color codes for terminal
GREEN = '\033[92m'
BLUE = '\033[94m'
YELLOW = '\033[93m'
RED = '\033[91m'
RESET = '\033[0m'


class OSCTester:
    def __init__(self, mode, desktop_ip=None, ios_ip=None):
        self.mode = mode
        self.desktop_ip = desktop_ip or "127.0.0.1"
        self.ios_ip = ios_ip or "127.0.0.1"
        self.messages_sent = 0
        self.messages_received = 0

    def ios_mode(self):
        """Simulate iOS app sending biofeedback to Desktop"""
        print(f"{GREEN}🍎 iOS Mode: Sending biofeedback to Desktop at {self.desktop_ip}:{DESKTOP_PORT}{RESET}\n")

        client = udp_client.SimpleUDPClient(self.desktop_ip, DESKTOP_PORT)

        # Simulate changing biofeedback data
        time_step = 0
        try:
            while True:
                # Simulate heart rate (60-120 BPM, sinusoidal)
                hr = 90 + 30 * math.sin(time_step * 0.1)

                # Simulate HRV (20-80 ms, slower oscillation)
                hrv = 50 + 30 * math.sin(time_step * 0.05)

                # Simulate breath rate (8-20 /min)
                breath = 14 + 6 * math.sin(time_step * 0.02)

                # Simulate coherence (0-1)
                coherence = 0.5 + 0.5 * math.sin(time_step * 0.03)

                # Send messages
                client.send_message("/echoel/bio/heartrate", hr)
                print(f"♥️  Heart Rate: {hr:.1f} bpm")

                client.send_message("/echoel/bio/hrv", hrv)
                print(f"🫀 HRV: {hrv:.1f} ms")

                client.send_message("/echoel/bio/breathrate", breath)
                print(f"🌬️  Breath Rate: {breath:.1f} /min")

                client.send_message("/echoel/param/hrv_coherence", coherence)
                print(f"🧘 Coherence: {coherence * 100:.1f}%")

                # Simulate voice pitch (random walk)
                pitch = 220 + 100 * math.sin(time_step * 0.2)
                confidence = 0.7 + 0.3 * math.sin(time_step * 0.15)
                client.send_message("/echoel/audio/pitch", [pitch, confidence])
                print(f"🎤 Pitch: {pitch:.1f} Hz (conf: {confidence:.2f})")

                print(f"{BLUE}📤 Sent 5 messages to Desktop{RESET}\n")
                self.messages_sent += 5

                time_step += 1
                time.sleep(1.0)  # 1 Hz update rate

        except KeyboardInterrupt:
            print(f"\n{YELLOW}Stopped. Sent {self.messages_sent} messages total.{RESET}")

    def desktop_mode(self):
        """Simulate Desktop receiving from iOS and sending analysis back"""
        print(f"{GREEN}🖥️  Desktop Mode:{RESET}")
        print(f"  - Receiving on port {DESKTOP_PORT}")
        print(f"  - Sending analysis to {self.ios_ip}:{IOS_PORT}\n")

        # Setup receiver
        disp = dispatcher.Dispatcher()
        disp.map("/echoel/bio/heartrate", self.handle_heartrate)
        disp.map("/echoel/bio/hrv", self.handle_hrv)
        disp.map("/echoel/bio/breathrate", self.handle_breathrate)
        disp.map("/echoel/audio/pitch", self.handle_pitch)
        disp.map("/echoel/param/*", self.handle_param)
        disp.set_default_handler(self.handle_unknown)

        # Setup sender (for analysis feedback)
        self.analysis_client = udp_client.SimpleUDPClient(self.ios_ip, IOS_PORT)

        # Start analysis feedback thread
        feedback_thread = threading.Thread(target=self.send_analysis_feedback, daemon=True)
        feedback_thread.start()

        # Start server
        server = osc_server.ThreadingOSCUDPServer(("0.0.0.0", DESKTOP_PORT), disp)
        print(f"{GREEN}✅ Desktop listening on port {DESKTOP_PORT}{RESET}")

        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print(f"\n{YELLOW}Stopped. Received {self.messages_received} messages.{RESET}")
            server.shutdown()

    def send_analysis_feedback(self):
        """Simulate Desktop sending FFT analysis to iOS"""
        time_step = 0
        while True:
            # Simulate RMS level (-40 to -10 dB)
            rms = -25 + 15 * math.sin(time_step * 0.3)
            self.analysis_client.send_message("/echoel/analysis/rms", rms)

            # Simulate Peak level (slightly higher than RMS)
            peak = rms + 5
            self.analysis_client.send_message("/echoel/analysis/peak", peak)

            # Simulate 8-band spectrum (logarithmic energy distribution)
            spectrum = []
            for i in range(8):
                # Lower frequencies typically have more energy
                energy = -30 + (8 - i) * 3 + 10 * math.sin(time_step * 0.2 + i)
                spectrum.append(energy)

            self.analysis_client.send_message("/echoel/analysis/spectrum", spectrum)

            print(f"{BLUE}📡 Sent analysis: RMS={rms:.1f}dB, Peak={peak:.1f}dB, Spectrum=[8 bands]{RESET}")

            time_step += 1
            time.sleep(0.333)  # 3 Hz (333ms)

    # Handlers for received messages
    def handle_heartrate(self, addr, hr):
        print(f"{GREEN}♥️  Received Heart Rate: {hr:.1f} bpm{RESET}")
        self.messages_received += 1

    def handle_hrv(self, addr, hrv):
        print(f"{GREEN}🫀 Received HRV: {hrv:.1f} ms{RESET}")
        self.messages_received += 1

    def handle_breathrate(self, addr, breath):
        print(f"{GREEN}🌬️  Received Breath Rate: {breath:.1f} /min{RESET}")
        self.messages_received += 1

    def handle_pitch(self, addr, freq, conf):
        print(f"{GREEN}🎤 Received Pitch: {freq:.1f} Hz (confidence: {conf:.2f}){RESET}")
        self.messages_received += 1

    def handle_param(self, addr, value):
        param_name = addr.split('/')[-1]
        print(f"{GREEN}🎚️  Received Parameter: {param_name} = {value:.3f}{RESET}")
        self.messages_received += 1

    def handle_unknown(self, addr, *args):
        print(f"{YELLOW}❓ Unknown message: {addr} {args}{RESET}")

    def interactive_mode(self):
        """Interactive mode: both sender and receiver"""
        print(f"{GREEN}🔄 Interactive Mode{RESET}")
        print(f"  - Press 1-5 to send test messages")
        print(f"  - Press 'q' to quit\n")

        client = udp_client.SimpleUDPClient(self.desktop_ip, DESKTOP_PORT)

        print("1. Send Heart Rate (80 bpm)")
        print("2. Send HRV (60 ms)")
        print("3. Send Breath Rate (12 /min)")
        print("4. Send Full Biofeedback Set")
        print("5. Send Stress Test (rapid messages)")
        print("q. Quit\n")

        while True:
            choice = input("Your choice: ").strip()

            if choice == '1':
                client.send_message("/echoel/bio/heartrate", 80.0)
                print(f"{GREEN}✅ Sent Heart Rate: 80 bpm{RESET}\n")

            elif choice == '2':
                client.send_message("/echoel/bio/hrv", 60.0)
                print(f"{GREEN}✅ Sent HRV: 60 ms{RESET}\n")

            elif choice == '3':
                client.send_message("/echoel/bio/breathrate", 12.0)
                print(f"{GREEN}✅ Sent Breath Rate: 12 /min{RESET}\n")

            elif choice == '4':
                client.send_message("/echoel/bio/heartrate", 75.0)
                client.send_message("/echoel/bio/hrv", 55.0)
                client.send_message("/echoel/bio/breathrate", 14.0)
                client.send_message("/echoel/param/hrv_coherence", 0.7)
                client.send_message("/echoel/audio/pitch", [220.0, 0.85])
                print(f"{GREEN}✅ Sent full biofeedback set{RESET}\n")

            elif choice == '5':
                print(f"{YELLOW}Stress testing with 100 messages...{RESET}")
                for i in range(100):
                    client.send_message("/echoel/bio/heartrate", 60.0 + i * 0.5)
                    time.sleep(0.01)  # 100 Hz
                print(f"{GREEN}✅ Sent 100 messages{RESET}\n")

            elif choice.lower() == 'q':
                print("Goodbye!")
                break

            else:
                print(f"{RED}Invalid choice{RESET}\n")


def main():
    parser = argparse.ArgumentParser(description="OSC Test Script for Echoelmusic")
    parser.add_argument("--mode", choices=["ios", "desktop", "interactive"],
                        default="interactive",
                        help="Test mode (default: interactive)")
    parser.add_argument("--desktop-ip", default="127.0.0.1",
                        help="Desktop IP address (default: 127.0.0.1)")
    parser.add_argument("--ios-ip", default="127.0.0.1",
                        help="iOS IP address (default: 127.0.0.1)")

    args = parser.parse_args()

    tester = OSCTester(args.mode, args.desktop_ip, args.ios_ip)

    if args.mode == "ios":
        tester.ios_mode()
    elif args.mode == "desktop":
        tester.desktop_mode()
    elif args.mode == "interactive":
        tester.interactive_mode()


if __name__ == "__main__":
    main()
