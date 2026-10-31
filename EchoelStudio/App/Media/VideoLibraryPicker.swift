import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The system picker for one video from the photo library (wave W7). It runs out of process and
/// asks for no library access: only the video picked reaches Echoel, as a copy in the temporary
/// folder that the import then copies into the song.
struct VideoLibraryPicker: UIViewControllerRepresentable {
    let pick: (URL) -> Void
    let cancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(pick: pick, cancel: cancel) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        // Without a photo library the configuration grants no access to it.
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency PHPickerViewControllerDelegate {
        let pick: (URL) -> Void
        let cancel: () -> Void
        private var answered = false

        init(pick: @escaping (URL) -> Void, cancel: @escaping () -> Void) {
            self.pick = pick
            self.cancel = cancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let type = UTType.movie.identifier
            guard let provider = results.first?.itemProvider, provider.hasItemConformingToTypeIdentifier(type) else {
                finish(nil)
                return
            }
            // The file exists only while this callback runs, on a queue of the picker's: it is
            // copied there, and the copy goes to the main actor once.
            provider.loadFileRepresentation(forTypeIdentifier: type) { @Sendable [weak self] url, _ in
                let kept = url.flatMap(VideoLibraryPicker.keep)
                Task { @MainActor [weak self] in self?.finish(kept) }
            }
        }

        private func finish(_ url: URL?) {
            guard !answered else { return }
            answered = true
            if let url { pick(url) } else { cancel() }
        }
    }

    /// A copy of a file the picker lends only for the length of its callback.
    nonisolated static func keep(_ url: URL) -> URL? {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Picked", isDirectory: true)
        let target = folder.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(VideoFileImport.fileExtension(of: url))
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: target)
            return target
        } catch {
            return nil
        }
    }
}
