#!/usr/bin/env swift

//
//  example_cli.swift
//  EchoelCalculator CLI Example
//
//  Demonstrates scientific BPM/frequency calculations
//

import Foundation

// Simple command-line interface for EchoelCalculator

print("""
═══════════════════════════════════════════════════════════
🧬 SCIENTIFIC ECHOEL CALCULATOR - CLI DEMO
═══════════════════════════════════════════════════════════

100% PEER-REVIEWED - KEINE ESOTERIK

Enter BPM to calculate (or 'q' to quit):
""")

while true {
    print("\nBPM: ", terminator: "")

    guard let input = readLine(), input.lowercased() != "q" else {
        print("\nExiting...\n")
        break
    }

    guard let bpm = Float(input), bpm > 0 else {
        print("❌ Invalid BPM. Please enter a number.")
        continue
    }

    // Calculate
    let output = ScientificEchoelCalculator.calculate(bpm: bpm)

    // Print summary
    print("\n" + ScientificEchoelCalculator.generateSummary(output))

    // Ask for export
    print("Export options:")
    print("  1. Reaper RPP")
    print("  2. Premiere Pro XML")
    print("  3. DaVinci Resolve EDL")
    print("  4. Final Cut Pro XML")
    print("  5. CSV (Universal)")
    print("  6. JSON")
    print("  s. Skip export")
    print("\nSelect export format (1-6 or s): ", terminator: "")

    if let exportChoice = readLine() {
        var filename = ""
        var content = ""

        switch exportChoice {
        case "1":
            content = DAWExportManager.exportToReaper(output, duration: 300.0)
            filename = "EchoelSync_\(Int(bpm))BPM.rpp"

        case "2":
            content = VideoExportManager.exportToPremiereXML(output, duration: 300.0)
            filename = "EchoelSync_\(Int(bpm))BPM_Premiere.xml"

        case "3":
            content = VideoExportManager.exportToResolveEDL(output, duration: 300.0)
            filename = "EchoelSync_\(Int(bpm))BPM_Resolve.edl"

        case "4":
            content = VideoExportManager.exportToFinalCutProXML(output, duration: 300.0)
            filename = "EchoelSync_\(Int(bpm))BPM_FCP.fcpxml"

        case "5":
            content = DAWExportManager.exportToCSV(output, duration: 300.0)
            filename = "EchoelSync_\(Int(bpm))BPM.csv"

        case "6":
            content = VideoExportManager.exportToJSON(output, duration: 300.0)
            filename = "EchoelSync_\(Int(bpm))BPM.json"

        case "s", "S":
            print("Skipping export.\n")
            continue

        default:
            print("Invalid choice. Skipping export.\n")
            continue
        }

        // Save file
        do {
            try DAWExportManager.saveToFile(content: content, filename: filename)
            print("✅ Exported to: \(filename)\n")
        } catch {
            print("❌ Export failed: \(error)\n")
        }
    }
}

print("""
═══════════════════════════════════════════════════════════
Thank you for using Scientific EchoelCalculator!

KEINE ESOTERIK. NUR WISSENSCHAFT. NUR EVIDENZ. 🔬
═══════════════════════════════════════════════════════════
""")

// MARK: - Example BPM Values for Testing

/*
SUGGESTED TEST VALUES:

60 BPM   - Delta range (sleep music)
72 BPM   - Theta range (meditation)
90 BPM   - Alpha range (relaxation)
120 BPM  - Beta range (focus)
160 BPM  - Gamma range (workout, cognitive)

SPECIAL:
80 BPM   - Produces 40Hz harmonic (MIT Gamma research!)

VIDEO SYNC TEST:
24 BPM   - Syncs perfectly with 24 fps cinema
30 BPM   - Syncs with 30 fps video
60 BPM   - Syncs with 60 fps gaming/HFR
120 BPM  - Syncs with 120 fps high-end
*/
