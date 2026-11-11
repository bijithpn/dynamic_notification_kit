import 'exceptions.dart';

enum DeliveryVehicle { bike, scooter, car, van, truck, walking }

enum DistanceUnit { km, miles }

enum DeliveryStatus {
  preparing,
  pickedUp,
  onTheWay,
  approaching,
  arrived,
  delivered,
  cancelled,
}

/// Immutable, validated snapshot of a delivery. Single source of truth for
/// every template and platform.
class DeliveryState {
  DeliveryState({
    required this.progress,
    this.status = DeliveryStatus.onTheWay,
    this.eta,
    this.distanceRemainingMeters,
    this.vehicle = DeliveryVehicle.scooter,
    this.distanceUnit = DistanceUnit.km,
    this.driverName,
    this.headline,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now() {
    if (progress.isNaN || progress < 0 || progress > 1) {
      throw const DynamicNotificationException(
        DynamicNotificationErrorCode.invalidState,
        'progress must be within 0.0..1.0',
      );
    }
    if (distanceRemainingMeters != null &&
        (distanceRemainingMeters!.isNaN || distanceRemainingMeters! < 0)) {
      throw const DynamicNotificationException(
        DynamicNotificationErrorCode.invalidState,
        'distanceRemainingMeters must be >= 0',
      );
    }
  }

  factory DeliveryState.fromMap(Map<Object?, Object?> m) => DeliveryState(
    progress: (m['progress']! as num).toDouble(),
    status: DeliveryStatus.values.byName(m['status']! as String),
    eta: m['etaMs'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['etaMs']! as int),
    distanceRemainingMeters: (m['distanceMeters'] as num?)?.toDouble(),
    vehicle: DeliveryVehicle.values.byName(m['vehicle']! as String),
    distanceUnit: DistanceUnit.values.byName(m['unit']! as String),
    driverName: m['driverName'] as String?,
    headline: m['headline'] as String?,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updatedAtMs']! as int),
  );

  final double progress;
  final DeliveryStatus status;
  final DateTime? eta;
  final double? distanceRemainingMeters;
  final DeliveryVehicle vehicle;
  final DistanceUnit distanceUnit;
  final String? driverName;
  final String? headline;
  final DateTime updatedAt;

  bool get isTerminal =>
      status == DeliveryStatus.delivered || status == DeliveryStatus.cancelled;

  /// Progress rounded to whole percent; used for dedup.
  int get progressPercent => (progress * 100).round();

  DeliveryState copyWith({
    double? progress,
    DeliveryStatus? status,
    DateTime? eta,
    double? distanceRemainingMeters,
    DeliveryVehicle? vehicle,
    DistanceUnit? distanceUnit,
    String? driverName,
    String? headline,
    DateTime? updatedAt,
  }) => DeliveryState(
    progress: progress ?? this.progress,
    status: status ?? this.status,
    eta: eta ?? this.eta,
    distanceRemainingMeters:
        distanceRemainingMeters ?? this.distanceRemainingMeters,
    vehicle: vehicle ?? this.vehicle,
    distanceUnit: distanceUnit ?? this.distanceUnit,
    driverName: driverName ?? this.driverName,
    headline: headline ?? this.headline,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, Object?> toMap() => {
    'progress': progress,
    'status': status.name,
    'etaMs': eta?.millisecondsSinceEpoch,
    'distanceMeters': distanceRemainingMeters,
    'vehicle': vehicle.name,
    'unit': distanceUnit.name,
    'driverName': driverName,
    'headline': headline,
    'updatedAtMs': updatedAt.millisecondsSinceEpoch,
  };
}
