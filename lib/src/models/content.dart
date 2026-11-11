import 'exceptions.dart';

/// Reference to a native icon (drawable name on Android, SF Symbol on iOS).
class DynamicIcon {
  const DynamicIcon({this.android, this.sfSymbol, this.emoji});

  final String? android;
  final String? sfSymbol;
  final String? emoji;

  Map<String, Object?> toMap() => {
    'android': android,
    'sfSymbol': sfSymbol,
    'emoji': emoji,
  };
}

/// Text with an optional short form for space-constrained surfaces.
class DynamicText {
  const DynamicText(this.text, {this.shortText});

  final String text;
  final String? shortText;

  String get short => shortText ?? text;

  Map<String, Object?> toMap() => {'text': text, 'short': short};
}

/// Progress with the previous value so native can animate the transition.
class DynamicProgress {
  DynamicProgress({
    required this.value,
    double? from,
    this.animationMs = 800,
    this.reduceMotion = false,
  }) : from = from ?? value {
    if (value.isNaN || value < 0 || value > 1) {
      throw const DynamicNotificationException(
        DynamicNotificationErrorCode.invalidState,
        'progress must be within 0.0..1.0',
      );
    }
  }

  final double value;
  final double from;
  final int animationMs;
  final bool reduceMotion;

  Map<String, Object?> toMap() => {
    'from': from,
    'to': value,
    'animationMs': reduceMotion ? 0 : animationMs,
    'reduceMotion': reduceMotion,
  };
}
