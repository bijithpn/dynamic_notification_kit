import 'exceptions.dart';

/// A WGS84 coordinate. Validates range on construction.
class GeoPoint {
  GeoPoint(this.latitude, this.longitude) {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw DynamicNotificationException(
        DynamicNotificationErrorCode.invalidCoordinates,
        'Invalid coordinates: $latitude, $longitude',
      );
    }
  }

  factory GeoPoint.fromMap(Map<Object?, Object?> m) =>
      GeoPoint((m['lat']! as num).toDouble(), (m['lng']! as num).toDouble());

  final double latitude;
  final double longitude;

  Map<String, Object?> toMap() => {'lat': latitude, 'lng': longitude};

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// An ordered polyline from origin to destination.
class DeliveryRoute {
  DeliveryRoute(this.points, {this.originLabel, this.destinationLabel}) {
    if (points.length < 2) {
      throw const DynamicNotificationException(
        DynamicNotificationErrorCode.invalidState,
        'A route needs at least two points.',
      );
    }
  }

  final List<GeoPoint> points;
  final String? originLabel;
  final String? destinationLabel;

  GeoPoint get origin => points.first;
  GeoPoint get destination => points.last;

  Map<String, Object?> toMap() => {
    'originLabel': originLabel,
    'destinationLabel': destinationLabel,
  };
}
