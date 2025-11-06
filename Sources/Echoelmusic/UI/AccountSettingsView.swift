import SwiftUI
import AuthenticationServices

/// Account settings view with Sign in with Apple and account deletion
///
/// **Purpose:** Implement TN3194 account deletion requirements
///
/// **Features:**
/// - Sign in with Apple button
/// - Account information display
/// - Account deletion with confirmation
/// - Token revocation status
/// - Privacy compliance
///
public struct AccountSettingsView: View {

    @StateObject private var signInManager = SignInWithAppleManager()

    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deletionError: Error?
    @State private var showDeletionError = false

    public init() {}

    public var body: some View {
        List {
            // Authentication Section
            Section(header: Text("Authentication")) {
                switch signInManager.authenticationState {
                case .unauthenticated, .failed:
                    // Sign in with Apple button
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { _ in
                            // Handled by SignInWithAppleManager
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .onTapGesture {
                        signInManager.signIn()
                    }

                case .authenticating:
                    HStack {
                        ProgressView()
                        Text("Signing in...")
                            .foregroundColor(.secondary)
                    }

                case .authenticated:
                    // User info
                    if let user = signInManager.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading) {
                                    if let fullName = user.fullName {
                                        Text(fullName)
                                            .font(.headline)
                                    }

                                    if let email = user.email {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Text("User ID: \(user.userID.prefix(12))...")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        Button(action: { signInManager.signOut() }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .foregroundColor(.red)
                        }
                    }

                case .deletingAccount:
                    HStack {
                        ProgressView()
                        Text("Deleting account...")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Privacy Section
            if signInManager.authenticationState == .authenticated {
                Section(header: Text("Privacy")) {
                    NavigationLink(destination: DataManagementView()) {
                        Label("Data & Privacy", systemImage: "hand.raised.fill")
                    }

                    Button(action: { showDeleteConfirmation = true }) {
                        Label("Delete Account", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                }
            }

            // Info Section
            Section(header: Text("About Sign in with Apple")) {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(
                        icon: "lock.shield.fill",
                        title: "Secure",
                        description: "Your data is encrypted and protected"
                    )

                    InfoRow(
                        icon: "eye.slash.fill",
                        title: "Private",
                        description: "Apple doesn't track your activity"
                    )

                    InfoRow(
                        icon: "envelope.fill",
                        title: "Control",
                        description: "Use Hide My Email to protect your inbox"
                    )
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}

            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .alert("Deletion Failed", isPresented: $showDeletionError) {
            Button("OK") {}
        } message: {
            if let error = deletionError {
                Text(error.localizedDescription)
            } else {
                Text("An unknown error occurred.")
            }
        }
    }

    // MARK: - Actions

    private func deleteAccount() {
        isDeletingAccount = true

        Task {
            do {
                try await signInManager.deleteAccount()

                // Show success message
                await MainActor.run {
                    isDeletingAccount = false
                }

            } catch {
                await MainActor.run {
                    deletionError = error
                    showDeletionError = true
                    isDeletingAccount = false
                }
            }
        }
    }
}

/// Info row component
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Data management view
struct DataManagementView: View {
    @StateObject private var signInManager = SignInWithAppleManager()

    var body: some View {
        List {
            Section(header: Text("Your Data")) {
                Text("Echoelmusic stores the following data:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    DataItem(icon: "waveform.path.ecg", text: "HRV and heart rate measurements")
                    DataItem(icon: "wind", text: "Breathing session data")
                    DataItem(icon: "brain.head.profile", text: "Coherence scores")
                    DataItem(icon: "mic.fill", text: "Voice recordings (if enabled)")
                    DataItem(icon: "gearshape.fill", text: "App settings and preferences")
                }
                .padding(.vertical, 8)
            }

            Section(header: Text("Data Deletion")) {
                Text("When you delete your account, all of your data will be permanently removed from our servers within 30 days.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Export Data")) {
                Button(action: exportData) {
                    Label("Export My Data", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exportData() {
        // TODO: Implement data export
        print("[AccountSettings] 📤 Export data requested")
    }
}

/// Data item row
struct DataItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.caption)
        }
    }
}

#Preview {
    NavigationView {
        AccountSettingsView()
    }
}
