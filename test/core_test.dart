import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter_test/flutter_test.dart';

DeliveryRoute route() =>
    DeliveryRoute([GeoPoint(0, 0), GeoPoint(0, 0.01), GeoPoint(0.01, 0.01)]);

Matcher throwsDne() => throwsA(isA<DynamicNotificationException>());

void main() {
  group('DeliveryState', () {
    test('validates progress and distance', () {
      expect(() => DeliveryState(progress: 1.2), throwsDne());
      expect(() => DeliveryState(progress: double.nan), throwsDne());
      expect(
        () => DeliveryState(progress: .5, distanceRemainingMeters: -1),
        throwsDne(),
      );
    });
    test('map round trip', () {
      final s = DeliveryState(
        progress: .4,
        eta: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        driverName: 'Sam',
        vehicle: DeliveryVehicle.bike,
      );
      final r = DeliveryState.fromMap(s.toMap());
      expect(r.progress, .4);
      expect(r.vehicle, DeliveryVehicle.bike);
      expect(r.driverName, 'Sam');
      expect(r.eta, s.eta);
    });
  });

  test('GeoPoint rejects invalid coordinates', () {
    expect(() => GeoPoint(91, 0), throwsDne());
    expect(() => GeoPoint(0, 181), throwsDne());
    expect(() => GeoPoint(double.nan, 0), throwsDne());
  });

  test('RouteProjector projects and is monotonic', () {
    final p = RouteProjector(route());
    final mid = p.progress(GeoPoint(0, 0.01));
    expect(mid, closeTo(.5, .02));
    expect(p.progress(GeoPoint(0, 0.005)), greaterThanOrEqualTo(mid));
    expect(p.progress(GeoPoint(0.01, 0.01)), closeTo(1, .001));
  });

  test('GpsSmoother rejects low accuracy and jumps, smooths otherwise', () {
    final s = GpsSmoother(maxAccuracyMeters: 50);
    final t0 = DateTime(2026);
    expect(s.accept(GpsFix(GeoPoint(0, 0), timestamp: t0)), isNotNull);
    expect(s.accept(GpsFix(GeoPoint(0, 0.001), accuracyMeters: 500)), isNull);
    expect(
      s.accept(
        GpsFix(GeoPoint(0, 0.1), timestamp: t0.add(const Duration(seconds: 1))),
      ),
      isNull,
    );
    final ok = s.accept(
      GpsFix(
        GeoPoint(0, 0.0002),
        timestamp: t0.add(const Duration(seconds: 30)),
      ),
    );
    expect(ok!.longitude, closeTo(0.0001, 1e-9));
  });

  test('UpdateGate order, dedup, throttle, completion lock', () {
    final t = DateTime(2026, 1, 1, 12);
    Duration s(int n) => Duration(seconds: n);
    final g = UpdateGate(minInterval: s(2));
    final a = DeliveryState(progress: .1, updatedAt: t);
    expect(g.evaluate(a, t), UpdateResult.sent);
    g.markSent(a, t);
    expect(
      g.evaluate(
        DeliveryState(progress: .1, updatedAt: t.add(s(5))),
        t.add(s(5)),
      ),
      UpdateResult.deduplicated,
    );
    expect(
      g.evaluate(
        DeliveryState(progress: .5, updatedAt: t.add(s(1))),
        t.add(s(1)),
      ),
      UpdateResult.throttled,
    );
    expect(
      g.evaluate(
        DeliveryState(progress: .5, updatedAt: t.subtract(s(1))),
        t.add(s(9)),
      ),
      UpdateResult.stale,
    );
    final done = DeliveryState(
      progress: 1,
      status: DeliveryStatus.delivered,
      updatedAt: t.add(s(1)),
    );
    expect(g.evaluate(done, t.add(s(1))), UpdateResult.sent);
    g.markSent(done, t.add(s(1)));
    expect(
      g.evaluate(
        DeliveryState(progress: .2, updatedAt: t.add(s(10))),
        t.add(s(10)),
      ),
      UpdateResult.rejectedCompleted,
    );
  });

  test('Templates serialize with type', () {
    expect(const CompactDeliveryTemplate().toMap()['type'], 'compact');
    final m = AnimatedRouteTemplate(route: route(), reduceMotion: true).toMap();
    expect(m['type'], 'animatedRoute');
    expect(m['animationMs'], 0);
    expect(const DeliveryCompletedTemplate().toMap()['dismissAfterMs'], 300000);
  });

  test('Minimal layout falls back when data missing', () {
    const c = CompactNotificationContent(
      title: DynamicText('Hi'),
      layout: CompactNotificationLayout.iconAndTimer,
    );
    expect(c.toMap()['layout'], 'iconAndText');
    final p = CompactNotificationContent(
      title: const DynamicText('Hi'),
      progress: DynamicProgress(value: .3),
      layout: CompactNotificationLayout.iconAndProgress,
    );
    expect(p.toMap()['layout'], 'iconAndProgress');
  });

  group('DeliveryController', () {
    late List<(String, Map<String, Object?>)> calls;
    late DateTime now;
    Future<Object?> invoker(String m, Map<String, Object?> a) async {
      calls.add((m, a));
      return null;
    }

    DeliveryController make({NativeInvoker? inv}) => DeliveryController(
      id: 'd1',
      template: AnimatedRouteTemplate(route: route()),
      initial: DeliveryState(progress: 0, updatedAt: now),
      invoker: inv ?? invoker,
      route: route(),
      gate: UpdateGate(minInterval: Duration.zero),
      clock: () => now,
      retryDelays: const [Duration.zero, Duration.zero],
    );

    void tick() => now = now.add(const Duration(seconds: 5));

    setUp(() {
      calls = [];
      now = DateTime(2026, 1, 1, 12);
    });

    test('start, update with from/to, complete, reject after', () async {
      final c = make();
      await c.begin();
      expect(calls.first.$1, 'startDelivery');
      tick();
      expect(await c.update(progress: .4, updatedAt: now), UpdateResult.sent);
      final prog = calls.last.$2['progress']! as Map;
      expect(prog['from'], 0);
      expect(prog['to'], .4);
      tick();
      expect(await c.complete(), UpdateResult.sent);
      expect(calls.last.$2['state'], containsPair('status', 'delivered'));
      expect(await c.update(progress: .5), UpdateResult.rejectedCompleted);
    });

    test('invalid coords throw; GPS drives progress monotonic', () async {
      final c = make();
      await c.begin();
      expect(() => c.updateLocation(99, 0), throwsDne());
      tick();
      await c.updateLocation(0, 0.01, speedMps: 10);
      expect(c.state.progress, closeTo(.5, .02));
      expect(c.state.eta, isNotNull);
      final p = c.state.progress;
      tick();
      await c.updateLocation(0, 0.005);
      expect(c.state.progress, greaterThanOrEqualTo(p));
    });

    test('bad accuracy keeps last progress (missing GPS)', () async {
      final c = make();
      await c.begin();
      final before = calls.length;
      await c.updateLocation(0, 0.01, accuracyMeters: 9999);
      expect(calls.length, before);
    });

    test('retries platform failures then succeeds', () async {
      var n = 0;
      final c = make(
        inv: (m, a) async {
          if (m == 'updateDelivery' && n++ < 2) {
            throw const DynamicNotificationException(
              DynamicNotificationErrorCode.platform,
              'boom',
            );
          }
          return null;
        },
      );
      await c.begin();
      tick();
      expect(await c.update(progress: .3, updatedAt: now), UpdateResult.sent);
      expect(n, 3);
    });

    test('non-retryable failure returns failed', () async {
      final c = make(
        inv: (m, a) async {
          if (m == 'updateDelivery') {
            throw const DynamicNotificationException(
              DynamicNotificationErrorCode.budgetExceeded,
              'limit',
            );
          }
          return null;
        },
      );
      await c.begin();
      tick();
      expect(await c.update(progress: .3, updatedAt: now), UpdateResult.failed);
    });

    test('updateLocation without route throws unsupported', () async {
      final c = DeliveryController(
        id: 'x',
        template: const CompactDeliveryTemplate(),
        initial: DeliveryState(progress: 0),
        invoker: invoker,
      );
      expect(() => c.updateLocation(0, 0), throwsDne());
    });
  });
}
