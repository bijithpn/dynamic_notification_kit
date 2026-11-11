import 'capabilities.dart';
import 'minimal.dart';

/// Base notification request (non-delivery).
class DynamicNotificationRequest {
  const DynamicNotificationRequest({
    required this.id,
    this.mode = DynamicNotificationMode.standard,
    this.compact,
    this.title,
    this.body,
  });

  final String id;
  final DynamicNotificationMode mode;
  final CompactNotificationContent? compact;
  final String? title;
  final String? body;

  Map<String, Object?> toMap() => {
    'id': id,
    'mode': mode.name,
    'compact': compact?.toMap(),
    'title': title ?? compact?.title.text,
    'body': body ?? compact?.body?.text,
  };
}
