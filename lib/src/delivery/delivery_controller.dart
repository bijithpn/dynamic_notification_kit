import 'dart:async';

import '../models/models.dart';
import '../templates/templates.dart';
import 'gps_smoother.dart';
import 'route_projector.dart';
import 'update_gate.dart';

/// Low-level transport (MethodChannel in production, fake in tests).
typedef NativeInvoker = Future<Object?> Function(
  String method,
  Map<String, Object?> args,
);

/// Handle for a running delivery notification.
class DeliveryController {
  DeliveryController({
    required this.id,
    required this.template,
    required DeliveryState initial,
    required NativeInvoker invoker,
    DeliveryRoute? route,
    UpdateGate? gate,
    GpsSmoother? smoother,
    DateTime Function()? clock,
    this.retryDelays = const [
      Duration(milliseconds: 300),
      Duration(seconds: 1),
      Duration(seconds: 3),
    ],
  }) : _invoke = invoker,
       _gate = gate ?? UpdateGate(),
       _smoother = smoother ?? GpsSmoother(),
       _projector = route == null ? null : RouteProjector(route),
       _clock = clock ?? DateTime.now,
       _state = initial;

  final String id;
  final DeliveryTemplate template;
  final List<Duration> retryDelays;
  final NativeInvoker _invoke;
  final UpdateGate _gate;
  final GpsSmoother _smoother;
  final RouteProjector? _projector;
  final DateTime Function() _clock;

  DeliveryState _state;
  DeliveryState? _pending;
  Timer? _trailing;
  bool _ended = false;
  final _results = StreamController<UpdateResult>.broadcast();
  final _errors = StreamController<DynamicNotificationException>.broadcast();

  DeliveryState get state => _state;
  bool get isEnded => _ended;
  Stream<UpdateResult> get results => _results.stream;
  Stream<DynamicNotificationException> get errors => _errors.stream;

  /// Used by the facade right after `start`.
  Future<void> begin() async {
    await _send('startDelivery', _state, template.toMap(), previous: null);
    _gate.markSent(_state, _clock());
  }

  /// Update from a plain progress value and/or fields.
  Future<UpdateResult> update({
    double? progress,
    DeliveryStatus? status,
    DateTime? eta,
    double? distanceRemainingMeters,
    String? headline,
    DateTime? updatedAt,
  }) => updateState(
    _state.copyWith(
      progress: progress,
      status: status,
      eta: eta,
      distanceRemainingMeters: distanceRemainingMeters,
      headline: headline,
      updatedAt: updatedAt,
    ),
  );

  Future<UpdateResult> updateState(DeliveryState next) async {
    if (_ended) return UpdateResult.rejectedCompleted;
    final now = _clock();
    final r = _gate.evaluate(next, now);
    switch (r) {
      case UpdateResult.rejectedCompleted:
        _errors.add(
          const DynamicNotificationException(
            DynamicNotificationErrorCode.alreadyCompleted,
            'Delivery already completed; update ignored.',
          ),
        );
      case UpdateResult.throttled:
        _pending = next; // coalesce: keep only the newest
        _trailing ??= Timer(_gate.remaining(now), _flushPending);
      case UpdateResult.sent:
        _trailing?.cancel();
        _trailing = null;
        _pending = null;
        final ok = await _sendWithRetry(next);
        if (!ok) {
          _results.add(UpdateResult.failed);
          return UpdateResult.failed;
        }
      case UpdateResult.deduplicated:
      case UpdateResult.stale:
      case UpdateResult.failed:
        break;
    }
    _results.add(r);
    return r;
  }

  /// Feed a GPS fix. Requires a route; missing/bad GPS keeps last progress.
  Future<UpdateResult> updateLocation(
    double lat,
    double lng, {
    double? accuracyMeters,
    double? speedMps,
    DateTime? timestamp,
  }) async {
    final proj = _projector;
    if (proj == null) {
      throw const DynamicNotificationException(
        DynamicNotificationErrorCode.unsupported,
        'updateLocation requires a DeliveryRoute.',
      );
    }
    final point = GeoPoint(lat, lng); // throws on invalid coordinates
    final smoothed = _smoother.accept(
      GpsFix(point, accuracyMeters: accuracyMeters, timestamp: timestamp),
    );
    if (smoothed == null) return UpdateResult.deduplicated; // rejected fix
    final p = proj.progress(smoothed);
    final remaining = proj.remainingMeters(smoothed);
    DateTime? eta;
    if (speedMps != null && speedMps > 0.5) {
      eta = _clock().add(Duration(seconds: (remaining / speedMps).round()));
    }
    return update(
      progress: p < _state.progress ? _state.progress : p, // monotonic
      distanceRemainingMeters: remaining,
      eta: eta,
      status: p >= 0.98 ? DeliveryStatus.arrived : null,
    );
  }

  Future<UpdateResult> complete({String? headline}) => updateState(
    _state.copyWith(
      progress: 1,
      status: DeliveryStatus.delivered,
      distanceRemainingMeters: 0,
      headline: headline,
    ),
  );

  /// Ends and removes the surface.
  Future<void> end({Duration? dismissAfter}) async {
    if (_ended) return;
    _ended = true;
    _trailing?.cancel();
    await _invoke('end', {
      'id': id,
      'dismissAfterMs': dismissAfter?.inMilliseconds,
    });
    await _results.close();
    await _errors.close();
  }

  Future<void> _flushPending() async {
    _trailing = null;
    final p = _pending;
    _pending = null;
    if (p != null && !_ended) await updateState(p);
  }

  Future<bool> _sendWithRetry(DeliveryState next) async {
    for (var attempt = 0; ; attempt++) {
      try {
        await _send('updateDelivery', next, template.toMap(), previous: _state);
        _gate.markSent(next, _clock());
        _state = next;
        return true;
      } on DynamicNotificationException catch (e) {
        _errors.add(e);
        if (e.code != DynamicNotificationErrorCode.platform ||
            attempt >= retryDelays.length) {
          return false;
        }
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  Future<void> _send(
    String method,
    DeliveryState s,
    Map<String, Object?> tpl, {
    required DeliveryState? previous,
  }) async {
    await _invoke(method, {
      'id': id,
      'state': s.toMap(),
      'template': tpl,
      // Native renders the transition; Dart never ticks at high frequency.
      'progress': DynamicProgress(
        value: s.progress,
        from: previous?.progress,
        reduceMotion: template.reduceMotion,
      ).toMap(),
    });
  }

  void dispose() {
    _trailing?.cancel();
  }
}
