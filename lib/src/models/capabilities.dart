/// Which presentation actually ends up on screen.
enum DynamicNotificationMode {
  /// Full rich surface (Live Activity / promoted Live Update).
  live,

  /// Ongoing notification with custom/progress layout.
  ongoing,

  /// Minimal icon + short text.
  minimal,

  /// Plain one-shot notification.
  standard,
}

class DynamicNotificationCapabilities {
  const DynamicNotificationCapabilities({
    required this.platform,
    required this.osVersion,
    required this.notificationsPermitted,
    required this.supportsLiveSurface,
    required this.supportsPromotedOngoing,
    required this.supportsDynamicIsland,
    required this.dynamicIslandIsHeuristic,
  });

  factory DynamicNotificationCapabilities.fromMap(Map<Object?, Object?> m) =>
      DynamicNotificationCapabilities(
        platform: m['platform']! as String,
        osVersion: (m['osVersion'] ?? '') as String,
        notificationsPermitted: m['notificationsPermitted'] == true,
        supportsLiveSurface: m['supportsLiveSurface'] == true,
        supportsPromotedOngoing: m['supportsPromotedOngoing'] == true,
        supportsDynamicIsland: m['supportsDynamicIsland'] == true,
        dynamicIslandIsHeuristic: m['dynamicIslandIsHeuristic'] == true,
      );

  final String platform;
  final String osVersion;
  final bool notificationsPermitted;

  /// Android 16 ProgressStyle / iOS Live Activities available.
  final bool supportsLiveSurface;

  /// Android 16 promoted ongoing (status-bar chip) permitted.
  final bool supportsPromotedOngoing;

  /// iOS only; derived from device model, so a heuristic.
  final bool supportsDynamicIsland;
  final bool dynamicIslandIsHeuristic;
}
