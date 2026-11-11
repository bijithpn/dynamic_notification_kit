import 'dart:math' as math;

import '../models/geo.dart';

/// Projects GPS fixes onto a route polyline and reports progress 0..1.
/// Uses a local equirectangular projection (accurate for city-scale routes).
class RouteProjector {
  RouteProjector(this.route) {
    final lat0 = route.points.first.latitude * math.pi / 180;
    _cosLat = math.cos(lat0);
    for (final p in route.points) {
      _xy.add(_toXY(p));
    }
    var total = 0.0;
    _cum.add(0);
    for (var i = 1; i < _xy.length; i++) {
      total += (_xy[i] - _xy[i - 1]).distance;
      _cum.add(total);
    }
    totalMeters = total;
  }

  static const _earthR = 6371000.0;

  final DeliveryRoute route;
  final List<_P> _xy = [];
  final List<double> _cum = [];
  late final double _cosLat;
  late final double totalMeters;
  double _best = 0;

  _P _toXY(GeoPoint p) => _P(
    p.longitude * math.pi / 180 * _cosLat * _earthR,
    p.latitude * math.pi / 180 * _earthR,
  );

  /// Meters along route of the closest point to [fix], monotonic (never
  /// decreases) so GPS jitter cannot move the vehicle backwards.
  double project(GeoPoint fix) {
    if (totalMeters == 0) return 0;
    final f = _toXY(fix);
    var bestDist = double.infinity;
    var along = 0.0;
    for (var i = 0; i < _xy.length - 1; i++) {
      final a = _xy[i], b = _xy[i + 1];
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final t = len2 == 0
          ? 0.0
          : (((f - a).dx * ab.dx + (f - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
      final proj = _P(a.dx + ab.dx * t, a.dy + ab.dy * t);
      final d = (f - proj).distance;
      if (d < bestDist) {
        bestDist = d;
        along = _cum[i] + ab.distance * t;
      }
    }
    _best = math.max(_best, along);
    return _best;
  }

  double progress(GeoPoint fix) => (project(fix) / totalMeters).clamp(0.0, 1.0);

  double remainingMeters(GeoPoint fix) => totalMeters - project(fix);
}

class _P {
  const _P(this.dx, this.dy);
  final double dx, dy;
  _P operator -(_P o) => _P(dx - o.dx, dy - o.dy);
  double get distance => math.sqrt(dx * dx + dy * dy);
}
