import ActivityKit
import SwiftUI
import WidgetKit

// MARK: helpers
@available(iOS 16.2, *)
extension DeliveryAttributes.ContentState {
    var emoji: String {
        switch vehicle {
        case "bike": return "🚲"
        case "car": return "🚗"
        case "van": return "🚐"
        case "truck": return "🚚"
        case "walking": return "🚶"
        default: return "🛵"
        }
    }
    var accent: Color {
        Color(.sRGB,
              red: Double((accentColor >> 16) & 0xFF) / 255,
              green: Double((accentColor >> 8) & 0xFF) / 255,
              blue: Double(accentColor & 0xFF) / 255)
    }
    var statusText: String {
        if let h = headline { return h }
        switch status {
        case "preparing": return "Preparing your order"
        case "pickedUp": return "Picked up"
        case "approaching": return "Driver is approaching"
        case "arrived": return "Driver has arrived"
        case "delivered": return message ?? "Delivered"
        case "cancelled": return "Cancelled"
        default: return "On the way"
        }
    }
    var distanceText: String? {
        guard let m = distanceMeters else { return nil }
        if unit == "miles" {
            let mi = m / 1609.344
            return mi < 0.1 ? "\(Int(m * 3.28084)) ft" : String(format: "%.1f mi", mi)
        }
        return m < 1000 ? "\(Int(m)) m" : String(format: "%.1f km", m / 1000)
    }
    var etaDate: Date? { etaMs.map { Date(timeIntervalSince1970: Double($0) / 1000) } }
    var isDone: Bool { status == "delivered" }
}

/// ETA that counts down; falls back to nothing when absent/past.
@available(iOS 16.2, *)
struct EtaText: View {
    let state: DeliveryAttributes.ContentState
    var body: some View {
        if let eta = state.etaDate, eta > Date(), !state.isDone {
            Text(timerInterval: Date()...eta, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else if state.isDone {
            Image(systemName: "checkmark.circle.fill")
        }
    }
}

// MARK: route track (vehicle moves from `fromProgress` to `progress`)
@available(iOS 16.2, *)
struct RouteTrack: View {
    let state: DeliveryAttributes.ContentState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        let reduce = state.reduceMotion || systemReduceMotion
        GeometryReader { geo in
            let w = geo.size.width
            let p = max(0, min(1, state.progress))
            let x = p * max(w - 20, 0)
            ZStack(alignment: .topLeading) {
                Capsule().fill(Color.gray.opacity(0.35)).frame(width: w, height: 5).offset(y: 28)
                Capsule().fill(state.accent).frame(width: x + 10, height: 5).offset(y: 28)
                Circle().stroke(state.accent, lineWidth: 2).frame(width: 10, height: 10).offset(x: w - 10, y: 25.5)
                Text(state.emoji).font(.system(size: 18)).frame(width: 20, height: 22).offset(x: x, y: 0)
            }
            .animation(reduce ? nil : .easeInOut(duration: Double(max(state.animationMs, 1)) / 1000),
                       value: state.progress)
        }
        .frame(height: 38)
        .accessibilityElement()
        .accessibilityLabel("Delivery progress")
        .accessibilityValue("\(Int(state.progress * 100)) percent")
    }
}

// MARK: lock screen / banner
@available(iOS 16.2, *)
struct DeliveryLockScreenView: View {
    let context: ActivityViewContext<DeliveryAttributes>
    var body: some View {
        let s = context.state
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.statusText).font(.headline).lineLimit(1)
                    if s.template == "driverApproaching", let d = s.distanceText {
                        Text("\(d) away").font(.subheadline).foregroundStyle(s.accent).lineLimit(1)
                    } else if let n = s.driverName {
                        Text(n).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                EtaText(state: s)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(s.accent)
                    .frame(maxWidth: 80, alignment: .trailing)
            }
            if s.template != "compact" && s.template != "completed" {
                RouteTrack(state: s)
                HStack {
                    Text(context.attributes.originLabel ?? "").lineLimit(1)
                    Spacer()
                    Text(context.attributes.destinationLabel ?? "").lineLimit(1)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}

// MARK: widget
@available(iOS 16.2, *)
struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { context in
            DeliveryLockScreenView(context: context)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text(s.emoji).font(.system(size: 28)) }
                DynamicIslandExpandedRegion(.trailing) {
                    EtaText(state: s)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(s.accent)
                        .frame(maxWidth: 70, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.statusText).font(.subheadline.weight(.semibold)).lineLimit(1)
                        RouteTrack(state: s)
                    }
                }
            } compactLeading: {
                Text(s.emoji)
            } compactTrailing: {
                EtaText(state: s).font(.caption2).frame(width: 44).foregroundStyle(s.accent)
            } minimal: {
                Text(s.emoji)
            }
            .keylineTint(s.accent)
        }
    }
}
