import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct MinimalIcon: View {
    let s: MinimalAttributes.ContentState
    var body: some View {
        if let e = s.emoji { Text(e) }
        else { Image(systemName: s.sfSymbol ?? "bell.fill") }
    }
}

@available(iOS 16.2, *)
struct MinimalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MinimalAttributes.self) { context in
            let s = context.state
            HStack(spacing: 10) {
                MinimalIcon(s: s).font(.title3)
                VStack(alignment: .leading) {
                    Text(s.title).font(.headline)
                    if let b = s.body { Text(b).font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 8)
                if s.layout == "iconAndTimer", let ms = s.countdownToMs {
                    let end = Date(timeIntervalSince1970: Double(ms) / 1000)
                    if end > Date() { Text(timerInterval: Date()...end, countsDown: true).monospacedDigit() }
                }
                if s.layout == "iconAndProgress", let p = s.progress {
                    ProgressView(value: p).frame(width: 80)
                }
            }
            .padding(14)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { MinimalIcon(s: s) }
                DynamicIslandExpandedRegion(.trailing) {
                    if let b = s.body { Text(b).font(.caption).lineLimit(1) }
                }
                DynamicIslandExpandedRegion(.bottom) { Text(s.title).font(.headline).lineLimit(1) }
            } compactLeading: { MinimalIcon(s: s) } compactTrailing: {
                Text(s.shortTitle).font(.caption2).lineLimit(1).frame(maxWidth: 48)
            } minimal: { MinimalIcon(s: s) }
        }
    }
}
