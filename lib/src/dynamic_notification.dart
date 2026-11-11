import 'dart:async';

import 'package:flutter/services.dart';

import 'delivery/delivery_controller.dart';
import 'models/models.dart';
import 'templates/templates.dart';

/// Event pushed from native (action tap, activity ended, push token).
class DynamicNotificationEvent {
  const DynamicNotificationEvent(this.type, this.id, this.data);
  final String type;
  final String? id;
  final Map<Object?, Object?> data;
}

/// Static facade for the plugin.
abstract final class DynamicNotification {
  static const MethodChannel _channel = MethodChannel(
    'dynamic_notification_kit',
  );
  static const EventChannel _events = EventChannel(
    'dynamic_notification_kit/events',
  );

  static Future<Object?> _invoke(String m, Map<String, Object?> a) async {
    try {
      return await _channel.invokeMethod<Object?>(m, a);
    } on PlatformException catch (e) {
      throw DynamicNotificationException(_code(e.code), e.message ?? e.code);
    }
  }

  static DynamicNotificationErrorCode _code(String c) {
    for (final v in DynamicNotificationErrorCode.values) {
      if (v.name == c) return v;
    }
    return DynamicNotificationErrorCode.platform;
  }

  /// Stream of native events.
  static Stream<DynamicNotificationEvent> get events =>
      _events.receiveBroadcastStream().map((e) {
        final m = (e as Map).cast<Object?, Object?>();
        return DynamicNotificationEvent(
          m['type']! as String,
          m['id'] as String?,
          m,
        );
      });

  static Future<DynamicNotificationCapabilities> getCapabilities() async {
    final m = await _invoke('getCapabilities', {});
    return DynamicNotificationCapabilities.fromMap(
      (m! as Map).cast<Object?, Object?>(),
    );
  }

  static Future<bool> requestPermission() async =>
      (await _invoke('requestPermission', {})) == true;

  /// Reports missing native configuration (manifest, Info.plist, widget ext).
  static Future<List<String>> diagnose() async {
    final r = await _invoke('diagnose', {});
    return ((r as List?) ?? const []).cast<String>();
  }

  /// Opens the OS settings page where the user can enable notifications,
  /// Live Activities (iOS) or Live Updates / promoted notifications
  /// (Android 16). Pass [promoted] to jump to the Live Updates toggle.
  static Future<void> openSettings({bool promoted = false}) =>
      _invoke('openSettings', {'promoted': promoted});

  static Future<void> start(DynamicNotificationRequest request) =>
      _invoke('start', request.toMap());

  static Future<void> update(DynamicNotificationRequest request) =>
      _invoke('update', request.toMap());

  static Future<void> end(String id) => _invoke('end', {'id': id});

  /// Starts a delivery tracker and returns its controller.
  static Future<DeliveryController> startDelivery({
    required String id,
    required DeliveryState state,
    DeliveryTemplate template = const DeliveryTrackingTemplate(),
    DeliveryRoute? route,
  }) async {
    final routeFromTemplate = switch (template) {
      DeliveryTrackingTemplate t => t.route,
      AnimatedRouteTemplate t => t.route,
      _ => null,
    };
    final c = DeliveryController(
      id: id,
      template: template,
      initial: state,
      invoker: _invoke,
      route: route ?? routeFromTemplate,
    );
    await c.begin();
    return c;
  }
}
