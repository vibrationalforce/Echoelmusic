# 🧪 Echoelmusic Test Scripts

Testing and validation tools for OSC communication.

---

## 📦 Installation

```bash
cd scripts
pip install -r requirements.txt
```

---

## 🎯 OSC Test Script

### Quick Start

```bash
# Interactive mode (easiest to start)
python osc_test.py --mode interactive

# Simulate iOS sending to Desktop
python osc_test.py --mode ios --desktop-ip 192.168.1.100

# Simulate Desktop receiving and sending back
python osc_test.py --mode desktop --ios-ip 192.168.1.50
```

---

## 🔧 Usage Examples

### 1. Test Desktop Reception

**Terminal 1 (Desktop simulator):**
```bash
python osc_test.py --mode desktop
```

**Terminal 2 (iOS simulator):**
```bash
python osc_test.py --mode ios --desktop-ip 127.0.0.1
```

You should see:
```
Terminal 1:
✅ Desktop listening on port 8000
♥️  Received Heart Rate: 90.0 bpm
🫀 Received HRV: 50.0 ms
🌬️  Received Breath Rate: 14.0 /min
📡 Sent analysis: RMS=-25.0dB, Peak=-20.0dB, Spectrum=[8 bands]

Terminal 2:
🍎 iOS Mode: Sending biofeedback to Desktop
♥️  Heart Rate: 90.0 bpm
🫀 HRV: 50.0 ms
...
```

---

### 2. Interactive Testing

```bash
python osc_test.py --mode interactive
```

**Menu:**
```
1. Send Heart Rate (80 bpm)
2. Send HRV (60 ms)
3. Send Breath Rate (12 /min)
4. Send Full Biofeedback Set
5. Send Stress Test (rapid messages)
q. Quit
```

Use this to manually test Desktop reception while it's running.

---

### 3. Real Device Testing

**On your computer (running Desktop app):**

Find your IP:
```bash
# macOS/Linux
ifconfig | grep "inet "

# Windows
ipconfig
```

Example output: `192.168.1.100`

**Run iOS simulator:**
```bash
python osc_test.py --mode ios --desktop-ip 192.168.1.100
```

Watch Desktop app - biofeedback values should update!

---

## 📊 What Gets Tested

### iOS → Desktop (Port 8000)

| Message | Parameters | Rate |
|---------|------------|------|
| `/echoel/bio/heartrate` | BPM (40-200) | 1 Hz |
| `/echoel/bio/hrv` | ms (0-200) | 1 Hz |
| `/echoel/bio/breathrate` | /min (5-30) | 1 Hz |
| `/echoel/param/hrv_coherence` | 0-1 | 1 Hz |
| `/echoel/audio/pitch` | Hz + confidence | 1 Hz |

### Desktop → iOS (Port 8001)

| Message | Parameters | Rate |
|---------|------------|------|
| `/echoel/analysis/rms` | dB (-80 to 0) | 3 Hz |
| `/echoel/analysis/peak` | dB (-80 to 0) | 3 Hz |
| `/echoel/analysis/spectrum` | 8 bands (dB) | 3 Hz |

---

## 🐛 Troubleshooting

### "Connection refused"

**Problem:** Desktop not listening on port 8000

**Solutions:**
- Start Desktop app first
- Check firewall allows UDP 8000
- Verify Desktop shows "Listening on port 8000"

### "No messages received"

**Problem:** Messages not getting through

**Solutions:**
- Check both devices on same network
- Verify IP addresses are correct
- Try `127.0.0.1` for local testing
- Check firewall allows UDP 8000 and 8001

### "Module not found: pythonosc"

**Problem:** Dependencies not installed

**Solution:**
```bash
pip install -r requirements.txt
```

---

## 📈 Performance Testing

### Latency Test

1. Run Desktop app
2. Run iOS simulator with timestamp:
```bash
time python osc_test.py --mode ios --desktop-ip YOUR_IP
```

3. Check Desktop logs for receive time
4. Latency should be <10ms on local network

### Stress Test

Interactive mode, option 5 sends 100 messages at 100 Hz:

```bash
python osc_test.py --mode interactive
# Choose: 5
```

Desktop should handle this without errors or audio glitches.

---

## 🔍 Debugging

### Verbose Output

All messages are logged with emojis and colors:
- 🟢 Green: Successful reception
- 🔵 Blue: Outgoing messages
- 🟡 Yellow: Warnings
- 🔴 Red: Errors

### Message Inspection

Watch network traffic:
```bash
# macOS/Linux
sudo tcpdump -i any -n udp port 8000 -X

# Or use Wireshark with filter: udp.port == 8000
```

---

## 🎨 Script Modes Explained

### iOS Mode
- Simulates iOS app sending biofeedback
- Uses sinusoidal patterns (realistic variation)
- Sends at 1 Hz (matches real app)
- Perfect for testing Desktop reception

### Desktop Mode
- Listens on port 8000 (like real Desktop app)
- Sends analysis to port 8001
- Displays all received messages
- Simulates FFT spectrum data

### Interactive Mode
- Manual message sending
- Test individual parameters
- Stress testing capabilities
- Great for debugging

---

## 📝 Example Session

```bash
# Terminal 1: Start Desktop simulator
$ python osc_test.py --mode desktop
🖥️  Desktop Mode:
  - Receiving on port 8000
  - Sending analysis to 127.0.0.1:8001

✅ Desktop listening on port 8000

# Terminal 2: Start iOS simulator
$ python osc_test.py --mode ios
🍎 iOS Mode: Sending biofeedback to Desktop at 127.0.0.1:8000

♥️  Heart Rate: 90.0 bpm
🫀 HRV: 50.0 ms
🌬️  Breath Rate: 14.0 /min
🧘 Coherence: 50.0%
🎤 Pitch: 220.0 Hz (conf: 0.70)
📤 Sent 5 messages to Desktop

# Back in Terminal 1:
♥️  Received Heart Rate: 90.0 bpm
🫀 Received HRV: 50.0 ms
🌬️  Received Breath Rate: 14.0 /min
🎚️  Received Parameter: hrv_coherence = 0.500
🎤 Received Pitch: 220.0 Hz (confidence: 0.70)
📡 Sent analysis: RMS=-25.0dB, Peak=-20.0dB, Spectrum=[8 bands]
```

---

## ✅ Success Checklist

After testing, verify:

- [ ] Desktop receives all biofeedback messages
- [ ] iOS receives spectrum data (if testing with receiver)
- [ ] No dropped messages
- [ ] Latency <10ms (local network)
- [ ] No errors in terminal
- [ ] Values update smoothly
- [ ] Desktop audio reacts (if running real app)

---

## 🚀 Next Steps

Once OSC communication works:

1. Test with real iOS app
2. Test with real Desktop app
3. Verify audio reactivity
4. Test on different networks
5. Measure actual latency
6. Optimize if needed

---

**See also:**
- `QUICK_START_GUIDE.md` - Complete setup guide
- `docs/osc-protocol.md` - Full OSC specification
- `docs/architecture.md` - System architecture

🎵 **Happy Testing!** 🧪
