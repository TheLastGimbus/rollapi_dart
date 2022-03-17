/// This file contains all the exceptions

/// Generic exception that something messed up with API
class RollApiException implements Exception {
  final String? message;

  RollApiException([this.message]);

  @override
  String toString() => 'RollApiException: $message';
}

/// Rate limit was exceeded and you need to wait to make new requests
class RollApiRateLimitException implements RollApiException {
  @override
  final String? message;

  /// DateTime when limit will be reset and you can try to make new requests
  final DateTime? limitReset;

  RollApiRateLimitException([this.message, this.limitReset]);

  @override
  String toString() => 'RollApiRateLimitException: $message | '
      'Limit reset: ${limitReset?.toString() ?? 'unknown'}';
}

/// While the base URL is ping-able, the API backend is currently unavailable
/// for some reason - for example, maintenance
class RollApiUnavailableException implements RollApiException {
  @override
  final String? message;

  RollApiUnavailableException([this.message]);

  @override
  String toString() => 'RollApiUnavailableException: $message';
}

/// Internal server error (500-ish)
class RollApiErrorException implements RollApiException {
  @override
  final String? message;

  RollApiErrorException([this.message]);

  @override
  String toString() => 'RollApiErrorException: $message';
}
