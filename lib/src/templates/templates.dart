import '../models/models.dart';

/// Pure presentation config. Serialises to one `template` map; all templates
/// share [DeliveryState] and the same update path.
sealed class DeliveryTemplate {
  const DeliveryTemplate({
    this.accentColor = 0xFF1E88E5,
    this.reduceMotion = false,
  });

  /// ARGB accent colour.
  final int accentColor;
  final bool reduceMotion;

  String get type;

  Map<String, Object?> toMap() => {
    'type': type,
    'accentColor': accentColor,
    'reduceMotion': reduceMotion,
  };
}

/// Full tracker: route line, moving vehicle, ETA.
class DeliveryTrackingTemplate extends DeliveryTemplate {
  const DeliveryTrackingTemplate({
    this.route,
    super.accentColor,
    super.reduceMotion,
  });
  final DeliveryRoute? route;

  @override
  String get type => 'tracking';

  @override
  Map<String, Object?> toMap() => {...super.toMap(), 'route': route?.toMap()};
}

/// Single-line, icon + ETA. Smallest delivery surface.
class CompactDeliveryTemplate extends DeliveryTemplate {
  const CompactDeliveryTemplate({super.accentColor, super.reduceMotion});
  @override
  String get type => 'compact';
}

/// Tracking with a smoothly animated vehicle along the route.
class AnimatedRouteTemplate extends DeliveryTemplate {
  const AnimatedRouteTemplate({
    required this.route,
    this.animationMs = 1200,
    super.accentColor,
    super.reduceMotion,
  });
  final DeliveryRoute route;
  final int animationMs;

  @override
  String get type => 'animatedRoute';

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    'route': route.toMap(),
    'animationMs': reduceMotion ? 0 : animationMs,
  };
}

/// Emphasises "driver approaching" with distance remaining.
class DriverApproachingTemplate extends DeliveryTemplate {
  const DriverApproachingTemplate({
    this.approachingThresholdMeters = 500,
    super.accentColor,
    super.reduceMotion,
  });
  final double approachingThresholdMeters;

  @override
  String get type => 'driverApproaching';

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    'approachingThresholdMeters': approachingThresholdMeters,
  };
}

/// Final "delivered" surface.
class DeliveryCompletedTemplate extends DeliveryTemplate {
  const DeliveryCompletedTemplate({
    this.message = 'Delivered',
    this.dismissAfter = const Duration(minutes: 5),
    super.accentColor,
    super.reduceMotion,
  });
  final String message;
  final Duration dismissAfter;

  @override
  String get type => 'completed';

  @override
  Map<String, Object?> toMap() => {
    ...super.toMap(),
    'message': message,
    'dismissAfterMs': dismissAfter.inMilliseconds,
  };
}
