import 'content.dart';

/// Layout of a minimal / compact notification.
enum CompactNotificationLayout {
  /// Small icon + one short line.
  iconAndText,

  /// Icon + chronometer / countdown.
  iconAndTimer,

  /// Icon + thin progress bar.
  iconAndProgress;

  /// Falls back to [iconAndText] when the requested layout lacks its data.
  CompactNotificationLayout resolve(CompactNotificationContent c) {
    switch (this) {
      case iconAndTimer:
        return c.countdownTo == null ? iconAndText : this;
      case iconAndProgress:
        return c.progress == null ? iconAndText : this;
      case iconAndText:
        return this;
    }
  }
}

class CompactNotificationContent {
  const CompactNotificationContent({
    required this.title,
    this.body,
    this.icon = const DynamicIcon(),
    this.countdownTo,
    this.progress,
    this.layout = CompactNotificationLayout.iconAndText,
  });

  final DynamicText title;
  final DynamicText? body;
  final DynamicIcon icon;
  final DateTime? countdownTo;
  final DynamicProgress? progress;
  final CompactNotificationLayout layout;

  Map<String, Object?> toMap() => {
    'title': title.toMap(),
    'body': body?.toMap(),
    'icon': icon.toMap(),
    'countdownToMs': countdownTo?.millisecondsSinceEpoch,
    'progress': progress?.toMap(),
    'layout': layout.resolve(this).name,
  };
}
