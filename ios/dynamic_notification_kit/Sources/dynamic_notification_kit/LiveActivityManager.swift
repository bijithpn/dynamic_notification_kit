import Foundation
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

struct KitError: Error {
    let code: String
    let message: String
}

typealias Args = [String: Any]

/// Owns Live Activities and the local-notification fallback.
final class LiveActivityManager {
    var emit: (([String: Any?]) -> Void)?
    private var lastUpdate: [String: Date] = [:]
    private let minInterval: TimeInterval = 1.0 // native-side budget guard

    // MARK: capabilities
    var liveSupported: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) { return ActivityAuthorizationInfo().areActivitiesEnabled }
        #endif
        return false
    }

    /// Device-model heuristic: iPhone 14 Pro and later, excluding 16e.
    static var hasDynamicIsland: Bool {
        var id = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? ""
        if id.isEmpty {
            var sys = utsname(); uname(&sys)
            id = withUnsafePointer(to: &sys.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
            }
        }
        guard id.hasPrefix("iPhone") else { return false }
        let parts = id.dropFirst(6).split(separator: ",").compactMap { Int($0) }
        guard parts.count == 2 else { return false }
        if id == "iPhone17,5" { return false }
        return parts[0] >= 16 || (parts[0] == 15 && parts[1] >= 2)
    }

    // MARK: delivery
    func delivery(_ a: Args, start: Bool) async throws {
        let id = a["id"] as! String
        let state = a["state"] as! [String: Any]
        let tpl = a["template"] as! [String: Any]
        let prog = a["progress"] as! [String: Any]

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *), liveSupported {
            let cs = DeliveryAttributes.ContentState(
                progress: (prog["to"] as? Double) ?? 0,
                fromProgress: (prog["from"] as? Double) ?? 0,
                animationMs: (prog["animationMs"] as? Int) ?? 0,
                reduceMotion: (prog["reduceMotion"] as? Bool) ?? false,
                status: state["status"] as? String ?? "onTheWay",
                etaMs: (state["etaMs"] as? NSNumber)?.int64Value,
                distanceMeters: state["distanceMeters"] as? Double,
                vehicle: state["vehicle"] as? String ?? "scooter",
                unit: state["unit"] as? String ?? "km",
                driverName: state["driverName"] as? String,
                headline: state["headline"] as? String,
                template: tpl["type"] as? String ?? "tracking",
                accentColor: UInt32(truncatingIfNeeded: (tpl["accentColor"] as? NSNumber)?.int64Value ?? 0xFF1E88E5),
                message: tpl["message"] as? String)
            let terminal = ["delivered", "cancelled"].contains(cs.status)
            let route = tpl["route"] as? [String: Any]
            let existing = Activity<DeliveryAttributes>.activities.first {
                $0.attributes.id == id && ($0.activityState == .active || $0.activityState == .stale)
            }
            if let act = existing {
                lastUpdate[id] = Date()
                let stale = cs.etaMs.map { Date(timeIntervalSince1970: Double($0) / 1000 + 600) }
                if terminal {
                    let after = (tpl["dismissAfterMs"] as? Int).map { Date().addingTimeInterval(Double($0) / 1000) }
                    await act.end(ActivityContent(state: cs, staleDate: nil),
                                  dismissalPolicy: after.map { .after($0) } ?? .default)
                    emit?(["type": "ended", "id": id])
                } else {
                    await act.update(ActivityContent(state: cs, staleDate: stale))
                }
            } else {
                do {
                    let attrs = DeliveryAttributes(id: id,
                                                   originLabel: route?["originLabel"] as? String,
                                                   destinationLabel: route?["destinationLabel"] as? String)
                    let act = try Activity.request(attributes: attrs,
                                                   content: ActivityContent(state: cs, staleDate: nil),
                                                   pushType: nil)
                    lastUpdate[id] = Date()
                    emit?(["type": "started", "id": id])
                    observe(act, id: id)
                } catch {
                    throw Self.map(error)
                }
            }
            return
        }
        #endif
        // Fallback: plain local notification (replaced in place by identifier).
        let status = state["status"] as? String ?? "onTheWay"
        let pct = Int(((prog["to"] as? Double) ?? 0) * 100)
        try await postLocal(id: id,
                            title: (state["headline"] as? String) ?? Self.statusText(status),
                            body: "\(pct)% of the way")
    }

    // MARK: minimal
    func minimal(_ a: Args) async throws {
        let id = a["id"] as! String
        let c = a["compact"] as? [String: Any] ?? [:]
        let title = c["title"] as? [String: Any]
        let body = (c["body"] as? [String: Any])?["text"] as? String
        let icon = c["icon"] as? [String: Any]
        let progress = (c["progress"] as? [String: Any])?["to"] as? Double

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *), liveSupported {
            let cs = MinimalAttributes.ContentState(
                title: title?["text"] as? String ?? "",
                shortTitle: title?["short"] as? String ?? "",
                body: body,
                countdownToMs: (c["countdownToMs"] as? NSNumber)?.int64Value,
                progress: progress,
                layout: c["layout"] as? String ?? "iconAndText",
                sfSymbol: icon?["sfSymbol"] as? String,
                emoji: icon?["emoji"] as? String)
            if let act = Activity<MinimalAttributes>.activities.first(where: {
                $0.attributes.id == id && ($0.activityState == .active || $0.activityState == .stale)
            }) {
                await act.update(ActivityContent(state: cs, staleDate: nil))
            } else {
                do {
                    _ = try Activity.request(attributes: MinimalAttributes(id: id),
                                             content: ActivityContent(state: cs, staleDate: nil))
                } catch { throw Self.map(error) }
            }
            return
        }
        #endif
        try await postLocal(id: id, title: title?["text"] as? String ?? "", body: body ?? "")
    }

    func standard(_ a: Args) async throws {
        try await postLocal(id: a["id"] as! String, title: a["title"] as? String ?? "", body: a["body"] as? String ?? "")
    }

    // MARK: end
    func end(id: String) async {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            for act in Activity<DeliveryAttributes>.activities where act.attributes.id == id {
                await act.end(nil, dismissalPolicy: .immediate)
            }
            for act in Activity<MinimalAttributes>.activities where act.attributes.id == id {
                await act.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
        lastUpdate[id] = nil
        emit?(["type": "ended", "id": id])
    }

    // MARK: helpers
    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private func observe(_ act: Activity<DeliveryAttributes>, id: String) {
        Task { [weak self] in
            for await s in act.activityStateUpdates where s == .ended || s == .dismissed {
                self?.emit?(["type": "ended", "id": id]); break
            }
        }
        Task { [weak self] in
            for await token in act.pushTokenUpdates {
                self?.emit?(["type": "pushToken", "id": id,
                             "token": token.map { String(format: "%02x", $0) }.joined()])
            }
        }
    }
    #endif

    private func postLocal(id: String, title: String, body: String) async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            throw KitError(code: "permissionDenied", message: "Notification permission not granted")
        }
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body
        try await center.add(UNNotificationRequest(identifier: id, content: c, trigger: nil))
    }

    static func map(_ e: Error) -> KitError {
        let d = String(describing: e).lowercased()
        if d.contains("exceeded") || d.contains("limit") { return KitError(code: "budgetExceeded", message: "\(e)") }
        if d.contains("denied") || d.contains("unentitled") { return KitError(code: "permissionDenied", message: "\(e)") }
        if d.contains("unsupported") { return KitError(code: "unsupported", message: "\(e)") }
        return KitError(code: "platform", message: "\(e)")
    }

    static func statusText(_ s: String) -> String {
        switch s {
        case "preparing": return "Preparing your order"
        case "pickedUp": return "Picked up"
        case "approaching": return "Driver is approaching"
        case "arrived": return "Driver has arrived"
        case "delivered": return "Delivered"
        case "cancelled": return "Cancelled"
        default: return "On the way"
        }
    }

    // MARK: diagnose
    func diagnose() -> [String] {
        var out: [String] = []
        let info = Bundle.main.infoDictionary ?? [:]
        if (info["NSSupportsLiveActivities"] as? Bool) != true {
            out.append("Info.plist is missing NSSupportsLiveActivities=true (run: dart run dynamic_notification_kit:setup --ios)")
        }
        let plugins = Bundle.main.builtInPlugInsURL
        let hasExt = plugins.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }?
            .contains { $0.pathExtension == "appex" } ?? false
        if !hasExt {
            out.append("No Widget Extension embedded; Live Activities will not render (run: dart run dynamic_notification_kit:setup --widget)")
        }
        return out
    }
}
