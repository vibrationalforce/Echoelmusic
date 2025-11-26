//
//  CrossPlatformUI.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  FUTURE-PROOF CROSS-PLATFORM UI COMPONENTS
//  Adaptive UI that works seamlessly across iOS, macOS, watchOS, visionOS
//

import SwiftUI

// MARK: - Adaptive Container

/// Container that adapts layout based on platform
struct AdaptiveContainer<Content: View>: View {
    @ObservedObject private var config = PlatformConfiguration.shared
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        switch config.currentPlatform {
        case .iOS, .visionOS:
            content
                .padding(config.recommendedPadding())

        case .macOS:
            content
                .padding(config.recommendedPadding())
                .frame(minWidth: 400, minHeight: 300)

        case .watchOS:
            content
                .padding(config.recommendedPadding())

        case .tvOS:
            content
                .padding(config.recommendedPadding())
                .focusable()

        case .unknown:
            content
                .padding()
        }
    }
}

// MARK: - Adaptive Grid

/// Grid that adapts column count based on platform
struct AdaptiveGrid<Item: Identifiable, ItemView: View>: View {
    @ObservedObject private var config = PlatformConfiguration.shared

    private let items: [Item]
    private let itemView: (Item) -> ItemView
    private let spacing: CGFloat

    init(
        items: [Item],
        spacing: CGFloat = 16,
        @ViewBuilder itemView: @escaping (Item) -> ItemView
    ) {
        self.items = items
        self.spacing = spacing
        self.itemView = itemView
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: config.recommendedColumnCount())

        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(items) { item in
                itemView(item)
            }
        }
    }
}

// MARK: - Adaptive Button

/// Button that adapts style based on platform
struct AdaptiveButton: View {
    @ObservedObject private var config = PlatformConfiguration.shared

    private let title: String
    private let systemImage: String?
    private let action: () -> Void
    private let style: ButtonStyle

    init(
        _ title: String,
        systemImage: String? = nil,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: {
            // Haptic feedback on supported platforms
            if config.currentPlatform.supportsHaptics {
                PlatformHaptics.impact(.light)
            }
            action()
        }) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .padding(.horizontal, buttonHorizontalPadding)
            .padding(.vertical, buttonVerticalPadding)
            .background(buttonBackground)
            .foregroundColor(buttonForeground)
            .cornerRadius(buttonCornerRadius)
        }
        .buttonStyle(.plain)  // Disable default style
    }

    private var buttonHorizontalPadding: CGFloat {
        switch config.idiom {
        case .phone, .watch: return 16
        case .tablet, .desktop, .headset: return 24
        case .tv: return 40
        }
    }

    private var buttonVerticalPadding: CGFloat {
        switch config.idiom {
        case .phone, .watch: return 12
        case .tablet, .desktop, .headset: return 16
        case .tv: return 20
        }
    }

    private var buttonBackground: Color {
        switch style {
        case .primary: return .accentColor
        case .secondary: return Color.gray.opacity(0.3)
        case .destructive: return .red
        case .plain: return .clear
        }
    }

    private var buttonForeground: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary, .plain: return .primary
        }
    }

    private var buttonCornerRadius: CGFloat {
        switch config.currentPlatform {
        case .iOS, .visionOS: return 12
        case .macOS: return 8
        case .watchOS: return 10
        case .tvOS: return 16
        case .unknown: return 10
        }
    }

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case plain
    }
}

// MARK: - Adaptive Navigation

/// Navigation that adapts based on platform
struct AdaptiveNavigation<Content: View>: View {
    @ObservedObject private var config = PlatformConfiguration.shared

    private let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        switch config.currentPlatform {
        case .iOS, .visionOS:
            NavigationView {
                content
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.large)
            }

        case .macOS:
            NavigationView {
                content
                    .navigationTitle(title)
                    .toolbar {
                        ToolbarItem(placement: .navigation) {
                            Text(title)
                                .font(.title)
                        }
                    }
            }

        case .watchOS:
            NavigationView {
                content
                    .navigationTitle(title)
            }

        case .tvOS:
            NavigationView {
                content
                    .navigationTitle(title)
            }

        case .unknown:
            NavigationView {
                content
                    .navigationTitle(title)
            }
        }
    }
}

// MARK: - Adaptive Card

/// Card component that adapts styling based on platform
struct AdaptiveCard<Content: View>: View {
    @ObservedObject private var config = PlatformConfiguration.shared

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(cardPadding)
            .background(cardBackground)
            .cornerRadius(cardCornerRadius)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    private var cardPadding: CGFloat {
        switch config.idiom {
        case .phone, .watch: return 16
        case .tablet, .desktop, .headset: return 20
        case .tv: return 32
        }
    }

    private var cardCornerRadius: CGFloat {
        switch config.currentPlatform {
        case .iOS, .visionOS: return 16
        case .macOS: return 12
        case .watchOS: return 12
        case .tvOS: return 20
        case .unknown: return 12
        }
    }

    private var cardBackground: Color {
        PlatformColor.secondaryBackground.swiftUIColor
    }

    private var shadowColor: Color {
        Color.black.opacity(0.1)
    }

    private var shadowRadius: CGFloat {
        switch config.currentPlatform {
        case .iOS, .visionOS: return 8
        case .macOS: return 4
        case .watchOS: return 2
        case .tvOS: return 12
        case .unknown: return 4
        }
    }

    private var shadowY: CGFloat {
        switch config.currentPlatform {
        case .iOS, .visionOS: return 4
        case .macOS: return 2
        case .watchOS: return 1
        case .tvOS: return 6
        case .unknown: return 2
        }
    }
}

// MARK: - Adaptive Toolbar

/// Toolbar that adapts based on platform capabilities
struct AdaptiveToolbar: View {
    @ObservedObject private var config = PlatformConfiguration.shared

    private let items: [ToolbarItem]

    init(items: [ToolbarItem]) {
        self.items = items
    }

    var body: some View {
        switch config.currentPlatform {
        case .iOS, .visionOS:
            HStack(spacing: 20) {
                ForEach(items) { item in
                    toolbarButton(for: item)
                }
            }
            .padding()

        case .macOS:
            HStack(spacing: 16) {
                ForEach(items) { item in
                    toolbarButton(for: item)
                }
            }
            .padding(.horizontal)

        case .watchOS:
            VStack(spacing: 12) {
                ForEach(items) { item in
                    toolbarButton(for: item)
                }
            }

        case .tvOS:
            HStack(spacing: 40) {
                ForEach(items) { item in
                    toolbarButton(for: item)
                }
            }
            .padding()

        case .unknown:
            HStack(spacing: 20) {
                ForEach(items) { item in
                    toolbarButton(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func toolbarButton(for item: ToolbarItem) -> some View {
        Button(action: item.action) {
            VStack(spacing: 4) {
                Image(systemName: item.systemImage)
                    .font(.system(size: iconSize))

                if config.idiom != .watch {
                    Text(item.title)
                        .font(.caption)
                }
            }
        }
        .accessibilityLabel(item.title)
    }

    private var iconSize: CGFloat {
        switch config.idiom {
        case .phone: return 20
        case .tablet: return 24
        case .desktop: return 22
        case .watch: return 18
        case .tv: return 32
        case .headset: return 24
        }
    }

    struct ToolbarItem: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
        let action: () -> Void
    }
}

// MARK: - Adaptive Modal

/// Modal presentation that adapts based on platform
struct AdaptiveModal<Content: View>: ViewModifier {
    @ObservedObject private var config = PlatformConfiguration.shared

    @Binding var isPresented: Bool
    let content: () -> Content

    func body(content: Content) -> some View {
        switch config.currentPlatform {
        case .iOS, .visionOS:
            content.sheet(isPresented: $isPresented) {
                self.content()
            }

        case .macOS:
            content.sheet(isPresented: $isPresented) {
                self.content()
                    .frame(minWidth: 400, minHeight: 300)
            }

        case .watchOS:
            content.sheet(isPresented: $isPresented) {
                self.content()
            }

        case .tvOS:
            content.fullScreenCover(isPresented: $isPresented) {
                self.content()
            }

        case .unknown:
            content.sheet(isPresented: $isPresented) {
                self.content()
            }
        }
    }
}

extension View {
    func adaptiveModal<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(AdaptiveModal(isPresented: isPresented, content: content))
    }
}

// MARK: - Adaptive List

/// List that adapts styling based on platform
struct AdaptiveList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    @ObservedObject private var config = PlatformConfiguration.shared

    private let data: Data
    private let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        List(data) { item in
            content(item)
                .listRowInsets(EdgeInsets(
                    top: rowInsetTop,
                    leading: rowInsetLeading,
                    bottom: rowInsetBottom,
                    trailing: rowInsetTrailing
                ))
        }
        .listStyle(listStyle)
    }

    private var listStyle: some ListStyle {
        switch config.currentPlatform {
        case .iOS, .visionOS:
            return AnyListStyle(.insetGrouped)
        case .macOS:
            return AnyListStyle(.sidebar)
        case .watchOS:
            return AnyListStyle(.plain)
        case .tvOS:
            return AnyListStyle(.plain)
        case .unknown:
            return AnyListStyle(.plain)
        }
    }

    private var rowInsetTop: CGFloat {
        switch config.idiom {
        case .phone, .watch: return 8
        case .tablet, .desktop, .headset: return 12
        case .tv: return 16
        }
    }

    private var rowInsetLeading: CGFloat {
        switch config.idiom {
        case .phone, .watch: return 16
        case .tablet, .desktop, .headset: return 20
        case .tv: return 32
        }
    }

    private var rowInsetBottom: CGFloat { rowInsetTop }
    private var rowInsetTrailing: CGFloat { rowInsetLeading }
}

// MARK: - List Style Wrapper

private struct AnyListStyle: ListStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ListStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Adaptive TextField

/// Text field that adapts based on platform
struct AdaptiveTextField: View {
    @ObservedObject private var config = PlatformConfiguration.shared

    private let title: String
    @Binding private var text: String
    private let prompt: String?

    init(_ title: String, text: Binding<String>, prompt: String? = nil) {
        self.title = title
        self._text = text
        self.prompt = prompt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if config.idiom != .watch {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField(prompt ?? title, text: $text)
                .textFieldStyle(textFieldStyle)
                .padding(textFieldPadding)
                .background(textFieldBackground)
                .cornerRadius(textFieldCornerRadius)
        }
    }

    private var textFieldStyle: some TextFieldStyle {
        switch config.currentPlatform {
        case .iOS, .visionOS, .watchOS:
            return AnyTextFieldStyle(.roundedBorder)
        case .macOS:
            return AnyTextFieldStyle(.squareBorder)
        case .tvOS:
            return AnyTextFieldStyle(.plain)
        case .unknown:
            return AnyTextFieldStyle(.plain)
        }
    }

    private var textFieldPadding: CGFloat {
        switch config.idiom {
        case .phone, .watch: return 12
        case .tablet, .desktop, .headset: return 16
        case .tv: return 20
        }
    }

    private var textFieldBackground: Color {
        PlatformColor.secondaryBackground.swiftUIColor
    }

    private var textFieldCornerRadius: CGFloat {
        switch config.currentPlatform {
        case .iOS, .visionOS: return 10
        case .macOS: return 6
        case .watchOS: return 8
        case .tvOS: return 12
        case .unknown: return 8
        }
    }
}

// MARK: - Text Field Style Wrapper

private struct AnyTextFieldStyle: TextFieldStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: TextFieldStyle>(_ style: S) {
        _makeBody = { configuration in
            AnyView(style._makeBody(configuration: configuration))
        }
    }

    func _makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Adaptive Spacing

extension CGFloat {
    static func adaptiveSpacing(_ baseSpacing: CGFloat = 16) -> CGFloat {
        let config = PlatformConfiguration.shared
        let multiplier: CGFloat

        switch config.idiom {
        case .phone: multiplier = 1.0
        case .tablet: multiplier = 1.25
        case .desktop: multiplier = 1.5
        case .watch: multiplier = 0.75
        case .tv: multiplier = 2.0
        case .headset: multiplier = 1.25
        }

        return baseSpacing * multiplier
    }
}

// MARK: - Platform-Specific Views

extension View {
    /// Execute action only on specific platform
    func onPlatform(_ platform: Platform, perform action: @escaping () -> Void) -> some View {
        self.onAppear {
            if Platform.current == platform {
                action()
            }
        }
    }

    /// Apply modifier only on specific platform
    func platformModifier<M: ViewModifier>(_ platform: Platform, modifier: M) -> some View {
        Group {
            if Platform.current == platform {
                self.modifier(modifier)
            } else {
                self
            }
        }
    }
}
