import Foundation

/// A tiny, local keyword parser that turns a musician's prompt ("fast dark trap, 140 bpm, Cm")
/// into a `VibeParameters` (wave W11.1b). No LLM call, no network — local heuristics only, so
/// the musician's prompt never leaves the device and the result is deterministic.
///
/// The parser is intentionally forgiving: unknown words are ignored, missing fields fall back
/// to the genre's house values from `VibeMatrix`. If no genre is named at all, the parser
/// returns `nil` — the caller then shows the matrix instead.
public enum VibePromptParser {

    public static func parse(_ prompt: String) -> VibeParameters? {
        let tokens = tokens(from: prompt)
        guard let genre = genre(from: tokens) else { return nil }
        let house = VibeMatrix.houseValues(for: genre)

        let energy = energy(from: tokens) ?? energyDefault(for: genre)
        let density = density(from: tokens) ?? densityDefault(for: genre)
        let brightness = brightness(from: tokens) ?? house.brightness
        let bpm = bpm(from: tokens) ?? house.bpm
        let keyRoot = keyRoot(from: tokens) ?? house.root
        let scale = scale(from: tokens, for: genre) ?? house.scale

        return VibeParameters(
            genre: genre,
            energy: energy,
            density: density,
            brightness: brightness,
            targetBPM: bpm,
            targetKeyRoot: keyRoot,
            targetScale: scale
        )
    }

    // MARK: - Tokenisation

    static func tokens(from prompt: String) -> [String] {
        var buffer = ""
        var out: [String] = []
        for ch in prompt.lowercased() {
            if ch.isLetter || ch.isNumber || ch == "." || ch == "#" || ch == "-" {
                buffer.append(ch)
            } else if !buffer.isEmpty {
                out.append(buffer); buffer = ""
            }
        }
        if !buffer.isEmpty { out.append(buffer) }
        return out
    }

    // MARK: - Genre

    static func genre(from tokens: [String]) -> VibeParameters.Genre? {
        for token in tokens {
            switch token {
            case "hiphop", "hip-hop", "rap", "trap", "boombap", "boom-bap", "drill", "phonk":
                return .hipHop
            case "chill", "lofi", "lo-fi", "chillhop", "chillwave", "downtempo", "lounge", "triphop", "trip-hop":
                return .chill
            case "score", "cinematic", "orchestral", "underscore", "ambient", "drone":
                return .score
            case "edm", "house", "techno", "trance", "dnb", "drum-and-bass", "dubstep", "hardstyle", "hardcore":
                return .edm
            default: continue
            }
        }
        return nil
    }

    // MARK: - Energy / density / brightness

    static func energy(from tokens: [String]) -> Double? {
        for token in tokens {
            switch token {
            case "calm", "slow", "gentle", "soft": return 0.15
            case "mellow", "chilled": return 0.3
            case "driving", "steady": return 0.6
            case "energetic", "aggressive", "intense", "banger", "hype": return 0.85
            case "wild", "rage", "hard": return 1
            default: continue
            }
        }
        return nil
    }

    static func density(from tokens: [String]) -> Double? {
        for token in tokens {
            switch token {
            case "minimal", "sparse", "empty": return 0.15
            case "simple", "clean": return 0.3
            case "busy", "layered", "full": return 0.7
            case "complex", "dense", "crowded": return 0.9
            default: continue
            }
        }
        return nil
    }

    static func brightness(from tokens: [String]) -> Double? {
        for token in tokens {
            switch token {
            case "dark", "deep", "muffled", "warm": return 0.2
            case "melancholic", "moody": return 0.35
            case "lush", "dreamy": return 0.6
            case "bright", "airy", "crisp", "shimmering", "uplifting": return 0.8
            default: continue
            }
        }
        return nil
    }

    // MARK: - BPM

    static func bpm(from tokens: [String]) -> Double? {
        for i in tokens.indices {
            let token = tokens[i]
            if let value = Double(token), value >= 40, value <= 240 {
                let next = i + 1 < tokens.count ? tokens[i + 1] : ""
                if next == "bpm" || next.isEmpty == false { return value }
                return value
            }
            if token.hasSuffix("bpm"), let value = Double(token.dropLast(3)), value >= 40, value <= 240 {
                return value
            }
        }
        return nil
    }

    // MARK: - Key root + scale

    static func keyRoot(from tokens: [String]) -> Int? {
        for token in tokens {
            if let root = Self.pitchClass(from: token) { return root }
        }
        return nil
    }

    static func pitchClass(from token: String) -> Int? {
        // Accepts "c", "c#", "db", "cm" (minor), "cmaj" (major); returns the root pitch class only.
        guard let first = token.first, first.isLetter else { return nil }
        let letters = "cdefgab"
        guard let letterOffset = letters.firstIndex(of: Character(String(first))) else { return nil }
        let letterIndex = letters.distance(from: letters.startIndex, to: letterOffset)
        let naturals = [0, 2, 4, 5, 7, 9, 11]
        var root = naturals[letterIndex]
        let rest = token.dropFirst()
        if rest.hasPrefix("#") { root += 1 }
        else if rest.hasPrefix("b") && !rest.hasPrefix("bm") { root -= 1 }
        root = ((root % 12) + 12) % 12
        return root
    }

    static func scale(from tokens: [String], for genre: VibeParameters.Genre) -> Scale? {
        for token in tokens {
            if token.hasSuffix("m") && token != "m" && Self.pitchClass(from: token) != nil {
                return .minor
            }
            switch token {
            case "major", "maj", "ionian": return .major
            case "minor", "min": return .minor
            case "dorian": return .dorian
            case "phrygian": return .phrygian
            case "lydian": return .lydian
            case "mixolydian": return .mixolydian
            case "pentatonic", "minorpentatonic": return .minorPentatonic
            case "majorpentatonic": return .majorPentatonic
            case "blues": return .blues
            case "chromatic": return .chromatic
            default: continue
            }
        }
        return nil
    }

    // MARK: - House defaults for energy/density when the prompt stays silent

    private static func energyDefault(for genre: VibeParameters.Genre) -> Double {
        switch genre {
        case .hipHop: return 0.55
        case .chill:  return 0.3
        case .score:  return 0.4
        case .edm:    return 0.75
        }
    }
    private static func densityDefault(for genre: VibeParameters.Genre) -> Double {
        switch genre {
        case .hipHop: return 0.5
        case .chill:  return 0.4
        case .score:  return 0.4
        case .edm:    return 0.65
        }
    }
}
