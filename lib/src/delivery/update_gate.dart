import '../models/delivery_state.dart';
import '../models/exceptions.dart';

/// Decides whether an update should be sent: ordering, dedup, throttle,
/// and post-completion lock. Pure logic; clock is passed in.
class UpdateGate {
  UpdateGate({this.minInterval = const Duration(seconds: 2)});

  final Duration minInterval;

  DeliveryState? _lastSent;
  DateTime? _lastSentAt;
  bool _completed = false;

  bool get completed => _completed;
  DeliveryState? get lastSent => _lastSent;

  /// Time to wait before a throttled update may be sent.
  Duration remaining(DateTime now) {
    if (_lastSentAt == null) return Duration.zero;
    final left = minInterval - now.difference(_lastSentAt!);
    return left.isNegative ? Duration.zero : left;
  }

  UpdateResult evaluate(DeliveryState next, DateTime now) {
    if (_completed) return UpdateResult.rejectedCompleted;
    final last = _lastSent;
    if (last != null) {
      if (next.updatedAt.isBefore(last.updatedAt)) return UpdateResult.stale;
      // Terminal states always go through, never deduped/throttled.
      if (!next.isTerminal) {
        if (_same(last, next)) return UpdateResult.deduplicated;
        if (remaining(now) > Duration.zero) return UpdateResult.throttled;
      }
    }
    return UpdateResult.sent;
  }

  void markSent(DeliveryState s, DateTime now) {
    _lastSent = s;
    _lastSentAt = now;
    if (s.isTerminal) _completed = true;
  }

  static int? _etaMinute(DeliveryState s) =>
      s.eta == null ? null : s.eta!.millisecondsSinceEpoch ~/ 60000;

  static bool _same(DeliveryState a, DeliveryState b) =>
      a.progressPercent == b.progressPercent &&
      a.status == b.status &&
      _etaMinute(a) == _etaMinute(b) &&
      a.headline == b.headline;
}
