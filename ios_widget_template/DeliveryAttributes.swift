import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// IMPORTANT: this file is duplicated verbatim in `ios_widget_template/` so the
/// Widget Extension and the app share the exact same Codable types.
@available(iOS 16.2, *)
public struct DeliveryAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var fromProgress: Double
        public var animationMs: Int
        public var reduceMotion: Bool
        public var status: String
        public var etaMs: Int64?
        public var distanceMeters: Double?
        public var vehicle: String
        public var unit: String
        public var driverName: String?
        public var headline: String?
        public var template: String
        public var accentColor: UInt32
        public var message: String?
    }
    public var id: String
    public var originLabel: String?
    public var destinationLabel: String?
}

@available(iOS 16.2, *)
public struct MinimalAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var shortTitle: String
        public var body: String?
        public var countdownToMs: Int64?
        public var progress: Double?
        public var layout: String
        public var sfSymbol: String?
        public var emoji: String?
    }
    public var id: String
}
#endif
