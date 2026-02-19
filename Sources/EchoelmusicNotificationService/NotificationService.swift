//
//  NotificationService.swift
//  EchoelmusicNotificationService
//
//  Notification Service Extension for rich push notifications.
//  Enables: image attachments, mutable content, silent background updates.
//

import UserNotifications

/// Notification Service Extension for Echoelmusic.
/// Intercepts push notifications before display to:
/// - Download and attach media (album art, waveforms)
/// - Modify notification content (localization, formatting)
/// - Handle silent data pushes for background sync
public final class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    public override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Download media attachment if URL provided
        if let mediaURLString = bestAttemptContent.userInfo["media_url"] as? String,
           let mediaURL = URL(string: mediaURLString) {
            downloadAttachment(from: mediaURL) { attachment in
                if let attachment {
                    bestAttemptContent.attachments = [attachment]
                }
                contentHandler(bestAttemptContent)
            }
            return
        }

        // Format notification based on category
        if let category = bestAttemptContent.userInfo["category"] as? String {
            formatForCategory(category, content: bestAttemptContent)
        }

        contentHandler(bestAttemptContent)
    }

    public override func serviceExtensionTimeWillExpire() {
        // Deliver best attempt before timeout (30s limit)
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Media Download

    private func downloadAttachment(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL, error == nil else {
                completion(nil)
                return
            }

            // Determine file extension from response
            let ext: String
            if let mimeType = (response as? HTTPURLResponse)?.mimeType {
                switch mimeType {
                case "image/png": ext = "png"
                case "image/jpeg", "image/jpg": ext = "jpg"
                case "image/gif": ext = "gif"
                default: ext = "jpg"
                }
            } else {
                ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            }

            // Copy to temp location with proper extension
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + "." + ext)

            do {
                try FileManager.default.moveItem(at: localURL, to: tempFile)
                let attachment = try UNNotificationAttachment(
                    identifier: "media",
                    url: tempFile,
                    options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }

    // MARK: - Category Formatting

    private func formatForCategory(_ category: String, content: UNMutableNotificationContent) {
        switch category {
        case "ECHOEL_WELLNESS":
            content.sound = UNNotificationSound(named: UNNotificationSoundName("wellness_chime.caf"))

        case "ECHOEL_SESSION":
            content.sound = UNNotificationSound(named: UNNotificationSoundName("session_start.caf"))

        case "ECHOEL_BIO_ALERT":
            content.sound = UNNotificationSound.defaultCritical
            content.interruptionLevel = .timeSensitive

        default:
            break
        }
    }
}
