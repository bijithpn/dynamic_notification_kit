/// Error codes surfaced by the plugin.
enum DynamicNotificationErrorCode {
  invalidState,
  invalidCoordinates,
  alreadyCompleted,
  permissionDenied,
  unsupported,
  notFound,
  budgetExceeded,
  platform,
}

/// Thrown (or reported on the error stream) when an operation fails.
class DynamicNotificationException implements Exception {
  const DynamicNotificationException(this.code, this.message);

  final DynamicNotificationErrorCode code;
  final String message;

  @override
  String toString() => 'DynamicNotificationException(${code.name}): $message';
}

/// Outcome of a single update attempt.
enum UpdateResult {
  sent,
  deduplicated,
  throttled,
  stale,
  rejectedCompleted,
  failed,
}
