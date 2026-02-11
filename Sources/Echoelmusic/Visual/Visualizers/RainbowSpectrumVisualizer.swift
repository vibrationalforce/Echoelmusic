import SwiftUI

// MARK: - Rainbow Spectrum Visualizer
// Physikalisch korrekte Regenbogen-Darstellung des Audio-Spektrums
// Basierend auf Oktav-analoger Übersetzung: Audio → Licht

struct RainbowSpectrumVisualizer: View {

    let params: UnifiedVisualSoundEngine.VisualParameters
    let spectrum: [Float]

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Schwarzer Hintergrund
                Color.black

                // Regenbogen-Spektrum Bars
                HStack(spacing: 1) {
                    ForEach(0..<spectrum.count, id: \.self) { index in
                        rainbowBar(index: index, total: spectrum.count, height: geo.size.height)
                    }
                }

                // 7-Band Overlay mit Labels
                VStack {
                    Spacer()
                    sevenBandOverlay(width: geo.size.width)
                }

                // Bio-Transposition Anzeige
                VStack {
                    bioTranspositionDisplay
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
    }

    // MARK: - Rainbow Bar

    @ViewBuilder
    private func rainbowBar(index: Int, total: Int, height: CGFloat) -> some View {
        let level = CGFloat(spectrum[index])

        // Berechne die Frequenz für diesen Bin (logarithmisch)
        let minFreq: Float = 20
        let maxFreq: Float = 20000
        let position = Float(index) / Float(total)
        let frequency = minFreq * pow(maxFreq / minFreq, position)

        // Hole die physikalisch korrekte Regenbogenfarbe
        let color = UnifiedVisualSoundEngine.OctaveTransposition.audioToColor(audioFrequency: frequency)

        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.3),
                        color,
                        color.opacity(0.8)
                    ]),
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: height * level * 0.8)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .shadow(color: color, radius: level > 0.5 ? 5 : 0)
    }

    // MARK: - 7-Band Overlay

    @ViewBuilder
    private func sevenBandOverlay(width: CGFloat) -> some View {
        let bands: [(name: String, level: Float, freq: Float)] = [
            ("SUB", params.subBassLevel, 40),
            ("BASS", params.bassLevel, 125),
            ("LOW", params.lowMidLevel, 355),
            ("MID", params.midLevel, 1000),
            ("HI-M", params.upperMidLevel, 2830),
            ("HIGH", params.highLevel, 5660),
            ("AIR", params.airLevel, 12650)
        ]

        HStack(spacing: 4) {
            ForEach(0..<bands.count, id: \.self) { i in
                let band = bands[i]
                let color = UnifiedVisualSoundEngine.OctaveTransposition.audioToColor(audioFrequency: band.freq)

                VStack(spacing: 2) {
                    // Level-Anzeige
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: (width / 7) - 8, height: CGFloat(band.level) * 60)
                        .shadow(color: color, radius: band.level > 0.5 ? 8 : 2)

                    // Label
                    Text(band.name)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Bio Transposition Display

    private var bioTranspositionDisplay: some View {
        HStack(spacing: 20) {
            // Heart Rate → Audio
            VStack(spacing: 4) {
                let heartAudio = UnifiedVisualSoundEngine.OctaveTransposition.heartRateToAudio(bpm: params.heartRate)
                let heartColor = UnifiedVisualSoundEngine.OctaveTransposition.heartRateToColor(bpm: params.heartRate)

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(heartColor)

                    Text("\(Int(params.heartRate))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(heartColor)

                    Text("BPM")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }

                HStack(spacing: 2) {
                    Text("→")
                        .foregroundColor(.gray)

                    Text(String(format: "%.1f Hz", heartAudio))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(heartColor)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)

            // Coherence → Color
            VStack(spacing: 4) {
                let coherenceColor = UnifiedVisualSoundEngine.OctaveTransposition.coherenceToColor(coherence: params.coherence)

                HStack(spacing: 4) {
                    Circle()
                        .fill(coherenceColor)
                        .frame(width: 12, height: 12)

                    Text("\(Int(params.coherence * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(coherenceColor)

                    Text("FLOW")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }

                Text(params.coherence > 0.6 ? "🟢 HIGH" : params.coherence > 0.3 ? "🟡 MED" : "🔴 LOW")
                    .font(.system(size: 10))
                    .foregroundColor(coherenceColor)
            }
            .padding(8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Rainbow Waveform Visualizer

struct RainbowWaveformVisualizer: View {

    let params: UnifiedVisualSoundEngine.VisualParameters
    let waveform: [Float]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                // Regenbogen-Waveform
                Path { path in
                    guard !waveform.isEmpty else { return }

                    let width = geo.size.width
                    let height = geo.size.height
                    let midY = height / 2
                    let stepX = width / CGFloat(waveform.count - 1)

                    path.move(to: CGPoint(x: 0, y: midY + CGFloat(waveform[0]) * midY * 0.8))

                    for i in 1..<waveform.count {
                        let x = CGFloat(i) * stepX
                        let y = midY + CGFloat(waveform[i]) * midY * 0.8
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: rainbowGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )

                // Frequenz-basierte Farbzone
                dominantFrequencyIndicator(size: geo.size)
            }
        }
    }

    private var rainbowGradient: [Color] {
        stride(from: 20, through: 20000, by: 2000).map { freq in
            UnifiedVisualSoundEngine.OctaveTransposition.audioToColor(audioFrequency: Float(freq))
        }
    }

    @ViewBuilder
    private func dominantFrequencyIndicator(size: CGSize) -> some View {
        let color = UnifiedVisualSoundEngine.OctaveTransposition.audioToColor(audioFrequency: params.frequency)

        VStack {
            HStack {
                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f Hz", params.frequency))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                        .shadow(color: color, radius: 10)

                    if params.pitch > 0 {
                        Text(midiNoteToName(Int(params.pitch)))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(color.opacity(0.8))
                    }
                }
                .padding()
            }

            Spacer()
        }
    }

    private func midiNoteToName(_ note: Int) -> String {
        let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        let noteName = notes[note % 12]
        return "\(noteName)\(octave)"
    }
}

// MARK: - Full Octave Transposition Visualizer

struct OctaveTranspositionVisualizer: View {

    let params: UnifiedVisualSoundEngine.VisualParameters

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Gradient Hintergrund basierend auf Coherence
                LinearGradient(
                    colors: [
                        UnifiedVisualSoundEngine.OctaveTransposition.coherenceToColor(coherence: params.coherence).opacity(0.3),
                        Color.black
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 30) {
                    // Titel
                    Text("OCTAVE TRANSPOSITION")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(4)

                    // Bio → Audio Section
                    bioToAudioSection

                    // Audio → Light Section
                    audioToLightSection

                    // Spektrum der Frequenzbänder
                    frequencyBandSpectrum
                }
                .padding()
            }
        }
    }

    // MARK: - Bio to Audio

    private var bioToAudioSection: some View {
        VStack(spacing: 12) {
            Text("BIO → AUDIO")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)

            HStack(spacing: 20) {
                // Heart
                transpositionCard(
                    icon: "heart.fill",
                    label: "HEART",
                    inputValue: "\(Int(params.heartRate)) BPM",
                    inputFreq: params.heartRate / 60,
                    octaves: 6,
                    outputFreq: UnifiedVisualSoundEngine.OctaveTransposition.heartRateToAudio(bpm: params.heartRate)
                )

                // Breath (simuliert)
                let breathRate: Float = 12 // Atemzüge pro Minute
                transpositionCard(
                    icon: "wind",
                    label: "BREATH",
                    inputValue: "\(Int(breathRate)) /min",
                    inputFreq: breathRate / 60,
                    octaves: 8,
                    outputFreq: UnifiedVisualSoundEngine.OctaveTransposition.breathToAudio(breathsPerMinute: breathRate)
                )

                // HRV
                let hrvFreq: Float = 0.1
                transpositionCard(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    inputValue: String(format: "%.2f Hz", hrvFreq),
                    inputFreq: hrvFreq,
                    octaves: 12,
                    outputFreq: UnifiedVisualSoundEngine.OctaveTransposition.hrvToAudio(hrvFrequency: hrvFreq)
                )
            }
        }
    }

    private func transpositionCard(icon: String, label: String, inputValue: String, inputFreq: Float, octaves: Int, outputFreq: Float) -> some View {
        let color = UnifiedVisualSoundEngine.OctaveTransposition.audioToColor(audioFrequency: outputFreq)

        return VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)

            Text(inputValue)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            Text("↓ +\(octaves) oct")
                .font(.system(size: 8))
                .foregroundColor(color.opacity(0.7))

            Text(String(format: "%.1f Hz", outputFreq))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Audio to Light

    private var audioToLightSection: some View {
        VStack(spacing: 12) {
            Text("AUDIO → LIGHT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)

            // Regenbogen-Leiste
            HStack(spacing: 0) {
                ForEach(0..<100, id: \.self) { i in
                    let freq = 20 * pow(Float(20000/20), Float(i) / 100)
                    let color = UnifiedVisualSoundEngine.OctaveTransposition.audioToColor(audioFrequency: freq)

                    Rectangle()
                        .fill(color)
                        .frame(width: 3, height: 30)
                }
            }
            .cornerRadius(4)

            // Frequenz-Labels
            HStack {
                Text("20 Hz")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.red)

                Spacer()

                Text("1 kHz")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.green)

                Spacer()

                Text("20 kHz")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.purple)
            }
            .padding(.horizontal, 4)

            // Wellenlängen
            HStack {
                Text("700 nm")
                    .font(.system(size: 7))
                    .foregroundColor(.gray)

                Spacer()

                Text("530 nm")
                    .font(.system(size: 7))
                    .foregroundColor(.gray)

                Spacer()

                Text("400 nm")
                    .font(.system(size: 7))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Frequency Band Spectrum

    private var frequencyBandSpectrum: some View {
        VStack(spacing: 8) {
            Text("7-BAND RAINBOW SPECTRUM")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)

            HStack(spacing: 4) {
                ForEach(UnifiedVisualSoundEngine.OctaveTransposition.bandCenters, id: \.name) { band in
                    let color = UnifiedVisualSoundEngine.OctaveTransposition.bandToRainbowColor(bandCenterFrequency: band.freq)

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .shadow(color: color, radius: 5)

                        Text(band.name)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(color)

                        Text("\(Int(band.wavelength))nm")
                            .font(.system(size: 6))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    RainbowSpectrumVisualizer(
        params: UnifiedVisualSoundEngine.VisualParameters(),
        spectrum: (0..<64).map { _ in Float.random(in: 0...1) }
    )
}
#endif
