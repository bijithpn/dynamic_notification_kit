import 'dart:async';
import 'dart:math';

import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';

/// A sample route (San Francisco, ~2.2 km).
final sampleRoute = DeliveryRoute(
  [
    GeoPoint(37.7749, -122.4194),
    GeoPoint(37.7790, -122.4130),
    GeoPoint(37.7840, -122.4090),
    GeoPoint(37.7890, -122.4010),
    GeoPoint(37.7930, -122.3960),
  ],
  originLabel: 'Restaurant',
  destinationLabel: 'Home',
);

/// Drives a [DeliveryController] along [sampleRoute] with optional faults.
class DeliverySimulator {
  DeliverySimulator(this.controller, {this.speedMps = 40});

  final DeliveryController controller;
  double speedMps; // sped up so demos finish quickly
  bool gpsNoise = false;
  bool dropouts = false;
  bool outOfOrder = false;

  final _rng = Random();
  final _projector = RouteProjector(sampleRoute);
  Timer? _timer;
  double _meters = 0;

  bool get running => _timer != null;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  GeoPoint _pointAt(double meters) {
    final pts = sampleRoute.points;
    var remaining = meters;
    for (var i = 0; i < pts.length - 1; i++) {
      final seg = RouteProjector(DeliveryRoute([pts[i], pts[i + 1]]))
          .totalMeters;
      if (remaining <= seg) {
        final t = seg == 0 ? 0 : remaining / seg;
        return GeoPoint(
          pts[i].latitude + (pts[i + 1].latitude - pts[i].latitude) * t,
          pts[i].longitude + (pts[i + 1].longitude - pts[i].longitude) * t,
        );
      }
      remaining -= seg;
    }
    return pts.last;
  }

  Future<void> _tick() async {
    _meters = min(_meters + speedMps, _projector.totalMeters);
    if (dropouts && _rng.nextDouble() < .3) return; // lost GPS fix
    var p = _pointAt(_meters);
    double? accuracy = 8;
    if (gpsNoise) {
      p = GeoPoint(
        p.latitude + (_rng.nextDouble() - .5) * 0.0004,
        p.longitude + (_rng.nextDouble() - .5) * 0.0004,
      );
      if (_rng.nextDouble() < .15) accuracy = 400; // poor fix, rejected
    }
    await controller.updateLocation(
      p.latitude,
      p.longitude,
      accuracyMeters: accuracy,
      speedMps: speedMps,
    );
    if (outOfOrder) {
      // A late packet carrying old data: the gate must drop it as stale.
      await controller.update(
        progress: 0,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );
    }
    if (_meters >= _projector.totalMeters) {
      stop();
      await controller.complete();
    }
  }
}
