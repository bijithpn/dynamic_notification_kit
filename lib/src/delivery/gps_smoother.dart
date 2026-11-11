import 'dart:math' as math;

import '../models/geo.dart';

/// A raw GPS fix.
class GpsFix {
  const GpsFix(this.point, {this.accuracyMeters, this.timestamp});
  final GeoPoint point;
  final double? accuracyMeters;
  final DateTime? timestamp;
}

/// Rejects poor/jumpy fixes and applies exponential smoothing.
class GpsSmoother {
  GpsSmoother({
    this.maxAccuracyMeters = 100,
    this.maxSpeedMps = 70,
    this.alpha = 0.5,
  });

  final double maxAccuracyMeters;
  final double maxSpeedMps;
  final double alpha;

  GeoPoint? _last;
  DateTime? _lastTime;

  GeoPoint? get last => _last;

  /// Returns the smoothed point, or `null` if [fix] was rejected (caller keeps
  /// the previous progress).
  GeoPoint? accept(GpsFix fix) {
    if (fix.accuracyMeters != null && fix.accuracyMeters! > maxAccuracyMeters) {
      return null;
    }
    final prev = _last;
    if (prev == null) {
      _last = fix.point;
      _lastTime = fix.timestamp;
      return fix.point;
    }
    final dist = _haversine(prev, fix.point);
    final dt = (fix.timestamp != null && _lastTime != null)
        ? fix.timestamp!.difference(_lastTime!).inMilliseconds / 1000
        : null;
    if (dt != null && dt > 0 && dist / dt > maxSpeedMps) return null; // jump
    final s = GeoPoint(
      prev.latitude + (fix.point.latitude - prev.latitude) * alpha,
      prev.longitude + (fix.point.longitude - prev.longitude) * alpha,
    );
    _last = s;
    _lastTime = fix.timestamp ?? _lastTime;
    return s;
  }

  static double _haversine(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLng = rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) *
            math.cos(rad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
