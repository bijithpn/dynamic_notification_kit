import 'package:dynamic_notification_kit/dynamic_notification_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('dynamic_notification_kit');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
          log.add(call);
          switch (call.method) {
            case 'getCapabilities':
              return {
                'platform': 'android',
                'osVersion': '36',
                'notificationsPermitted': true,
                'supportsLiveSurface': true,
                'supportsPromotedOngoing': false,
                'supportsDynamicIsland': false,
                'dynamicIslandIsHeuristic': false,
              };
            case 'requestPermission':
              return false;
            case 'diagnose':
              return ['missing X'];
            case 'start':
              throw PlatformException(code: 'permissionDenied', message: 'no');
          }
          return null;
        });
  });

  test('capabilities / permission / diagnose', () async {
    final c = await DynamicNotification.getCapabilities();
    expect(c.supportsLiveSurface, true);
    expect(await DynamicNotification.requestPermission(), false);
    expect(await DynamicNotification.diagnose(), ['missing X']);
  });

  test('permission denied maps to typed exception', () async {
    expect(
      () =>
          DynamicNotification.start(const DynamicNotificationRequest(id: 'a')),
      throwsA(
        isA<DynamicNotificationException>().having(
          (e) => e.code,
          'code',
          DynamicNotificationErrorCode.permissionDenied,
        ),
      ),
    );
  });

  test('startDelivery sends startDelivery then update', () async {
    final c = await DynamicNotification.startDelivery(
      id: 'd',
      state: DeliveryState(progress: 0),
    );
    expect(log.single.method, 'startDelivery');
    await c.end();
    expect(log.last.method, 'end');
  });

  test('minimal request serialises', () async {
    final m = DynamicNotificationRequest(
      id: 'm',
      mode: DynamicNotificationMode.minimal,
      compact: CompactNotificationContent(
        title: const DynamicText('Timer', shortText: 'T'),
        countdownTo: DateTime.fromMillisecondsSinceEpoch(5000),
        layout: CompactNotificationLayout.iconAndTimer,
      ),
    ).toMap();
    expect(m['mode'], 'minimal');
    expect((m['compact']! as Map)['layout'], 'iconAndTimer');
  });
}
