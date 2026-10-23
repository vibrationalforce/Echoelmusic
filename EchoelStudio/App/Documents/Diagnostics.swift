import EchoelCore
import Foundation

extension DiagnosticLog {
    /// The app's log, in a Diagnostics folder beside the songs: the Files app shows it under the
    /// app's name, and the musician shares it from there (NEUPLANUNG §6). The song library lists
    /// packages only, so the folder is never taken for a song.
    static let app = DiagnosticLog(url: DocumentController.defaultDirectory
        .appendingPathComponent("Diagnostics", isDirectory: true)
        .appendingPathComponent("Echoel diagnostics.log"))

    /// Starts this run's log with the app's version and build, before anything else at launch.
    /// The folder stays out of backups: what it says is about this device.
    static func beginApp() {
        let info = Bundle.main.infoDictionary
        app.begin(version: info?["CFBundleShortVersionString"] as? String ?? "?",
                  build: info?["CFBundleVersion"] as? String ?? "?")
        var folder = app.url.deletingLastPathComponent()
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
    }
}
