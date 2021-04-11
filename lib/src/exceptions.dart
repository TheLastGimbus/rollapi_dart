/// This file contains all the exceptions

/// Generic exception that something messed up with API
class ApiException implements Exception {
  final String message;

  ApiException([this.message]);

  @override
  String toString() => 'ApiException: $message';
}

/// Represents that rate limit was exceeded and you need to wait to make
/// new requests
class RateLimitException implements ApiException {
  @override
  final String message;

  /// DateTime when limit will be reset and you can make new requests
  final DateTime limitReset;

  RateLimitException(this.message, {this.limitReset});

  @override
  String toString() => 'RateLimitException: $message | '
      'Limit reset: ${limitReset?.toString() ?? 'unknown'}';
}

/// Represents that while the base URL is ping-able, the API backend is
/// currently unavailable for some reason - for example, maintenance
class ApiUnavailableException implements ApiException {
  @override
  final String message;

  ApiUnavailableException([this.message]);

  @override
  String toString() => 'ApiUnavailableException: $message';
}
