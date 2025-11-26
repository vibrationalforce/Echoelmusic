//
//  ChatView.swift
//  EOEL
//
//  Created: 2025-11-25
//
//  CHAT VIEW - Live chat from all platforms
//

import SwiftUI

struct ChatView: View {
    @StateObject private var liveEngine = LiveStreamingEngine.shared
    @State private var messageText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chat")
                    .font(.headline)

                Spacer()

                Text("\(liveEngine.chatMessages.count) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Messages
            ScrollView {
                if liveEngine.chatMessages.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No messages yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Messages from viewers will appear here when you go live")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(liveEngine.chatMessages) { message in
                            ChatMessageRow(message: message)
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // Send message
            HStack {
                TextField("Send a message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.accentColor)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .background(Color.gray.opacity(0.05))
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        liveEngine.sendChatMessage(messageText, to: .youtube)
        messageText = ""
    }
}

struct ChatMessageRow: View {
    let message: LiveStreamingEngine.ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Platform badge
            Image(systemName: platformIcon)
                .font(.caption)
                .foregroundColor(platformColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                // Username with badges
                HStack(spacing: 4) {
                    Text(message.username)
                        .font(.caption)
                        .fontWeight(.semibold)

                    if message.isModerator {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    if message.isSubscriber {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }

                // Message
                Text(message.message)
                    .font(.caption)
                    .foregroundColor(.primary)

                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var platformIcon: String {
        switch message.platform {
        case .youtube: return "play.rectangle.fill"
        case .twitch: return "gamecontroller.fill"
        case .facebook: return "person.2.fill"
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .twitter: return "bird.fill"
        case .linkedin: return "briefcase.fill"
        case .custom: return "message.fill"
        }
    }

    private var platformColor: Color {
        switch message.platform {
        case .youtube: return .red
        case .twitch: return .purple
        case .facebook: return .blue
        case .instagram: return .pink
        case .tiktok: return .cyan
        case .twitter: return .blue
        case .linkedin: return .blue
        case .custom: return .gray
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .frame(width: 350, height: 600)
    }
}
#endif
