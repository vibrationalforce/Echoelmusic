import Foundation

/// Where the sky is drawn from, and which source wins. A place the musician chose stays until they
/// choose another or go back to "Here": a location fix that arrives afterwards does not take it
/// away (it is kept, for the moment they go back). A fix replaces a place remembered from an
/// earlier night; "Here" falls back to that remembered place while no fix has come. Coordinates
/// outside the globe are refused.
public struct SkyPlace: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        /// Nothing yet: the view asks for a place.
        case none
        /// The last fix, from an earlier time.
        case remembered
        /// A fix from this time.
        case located
        /// A reference place the musician chose, by its name.
        case chosen(String)
    }

    public private(set) var source: Source = .none
    public private(set) var latitude: Double?
    public private(set) var longitude: Double?
    /// The newest fix, also while a chosen place is shown: "Here" goes back to it.
    public private(set) var lastFix: (latitude: Double, longitude: Double)? {
        get {
            guard let fixLatitude, let fixLongitude else { return nil }
            return (latitude: fixLatitude, longitude: fixLongitude)
        }
        set {
            fixLatitude = newValue?.latitude
            fixLongitude = newValue?.longitude
        }
    }
    private var fixLatitude: Double?
    private var fixLongitude: Double?
    /// The place remembered from an earlier time, kept as the fallback for "Here".
    private var rememberedLatitude: Double?
    private var rememberedLongitude: Double?

    /// There is a remembered place to go back to.
    public var hasRememberedPlace: Bool { rememberedLatitude != nil && rememberedLongitude != nil }

    public init() {}

    public static func isOnTheGlobe(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
    }

    /// A place remembered from an earlier time. It is kept as the fallback for "Here", and shown only
    /// while nothing better is known; true when it is shown.
    @discardableResult
    public mutating func remember(latitude: Double, longitude: Double) -> Bool {
        guard Self.isOnTheGlobe(latitude: latitude, longitude: longitude) else { return false }
        rememberedLatitude = latitude
        rememberedLongitude = longitude
        guard source == .none else { return false }
        self.latitude = latitude
        self.longitude = longitude
        source = .remembered
        return true
    }

    /// The musician chose a reference place: it is shown until they choose otherwise.
    @discardableResult
    public mutating func choose(_ name: String, latitude: Double, longitude: Double) -> Bool {
        guard !name.isEmpty, Self.isOnTheGlobe(latitude: latitude, longitude: longitude) else { return false }
        self.latitude = latitude
        self.longitude = longitude
        source = .chosen(name)
        return true
    }

    /// A location fix arrived. It is kept either way; it is shown unless a chosen place stands.
    /// True when the shown place changed.
    @discardableResult
    public mutating func located(latitude: Double, longitude: Double) -> Bool {
        guard Self.isOnTheGlobe(latitude: latitude, longitude: longitude) else { return false }
        lastFix = (latitude: latitude, longitude: longitude)
        if case .chosen = source { return false }
        self.latitude = latitude
        self.longitude = longitude
        source = .located
        return true
    }

    /// The musician goes back to "Here": the newest fix when there is one, else the remembered place,
    /// else nothing until the next fix arrives.
    public mutating func useHere() {
        if let fix = lastFix {
            latitude = fix.latitude
            longitude = fix.longitude
            source = .located
        } else if let rememberedLatitude, let rememberedLongitude {
            latitude = rememberedLatitude
            longitude = rememberedLongitude
            source = .remembered
        } else {
            latitude = nil
            longitude = nil
            source = .none
        }
    }

    /// Where "Here" would land: this time's fix, else the remembered place, else nothing.
    public var hereSource: Source {
        if lastFix != nil { return .located }
        return hasRememberedPlace ? .remembered : .none
    }

    /// The name of the chosen place, nil otherwise.
    public var chosenName: String? {
        if case let .chosen(name) = source { return name }
        return nil
    }

    public static func == (lhs: SkyPlace, rhs: SkyPlace) -> Bool {
        lhs.source == rhs.source && lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
            && lhs.fixLatitude == rhs.fixLatitude && lhs.fixLongitude == rhs.fixLongitude
            && lhs.rememberedLatitude == rhs.rememberedLatitude && lhs.rememberedLongitude == rhs.rememberedLongitude
    }
}
