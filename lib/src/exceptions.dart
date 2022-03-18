/// Generic exception for API
///
/// All of those exception mean that something happened *with the API itself* -
/// meaning, that all HTTP stuff went okay, it's just the RollER that messed up
class RollApiException implements Exception {
  final Uri url;
  final String? message;

  const RollApiException(this.url, [this.message]);

  @override
  String toString() => 'RollApiException on [$url]: : $message';
}

/// Content you're trying to reach is expired (or never existed at all)
///
/// Not that this will not be thrown in [RollApiClient.watchRoll()]
class RollApiExpiredException implements RollApiException {
  @override
  final Uri url;
  @override
  final String? message;

  RollApiExpiredException(this.url, [this.message]);

  @override
  String toString() => 'RollApiExpiredException on [$url]';
}

/// Rate limit was exceeded and you need to wait to make new requests
class RollApiRateLimitException implements RollApiException {
  @override
  final Uri url;
  @override
  final String? message;

  /// DateTime when limit will be reset and you can try to make new requests
  final DateTime? limitReset;

  const RollApiRateLimitException(this.url, [this.message, this.limitReset]);

  @override
  String toString() => 'RollApiRateLimitException on [$url]: $message | '
      'Limit reset: ${limitReset?.toString() ?? 'unknown'}';
}

/// While the base URL is ping-able, the API backend is currently unavailable
/// for some reason - for example, maintenance
class RollApiUnavailableException implements RollApiException {
  @override
  final Uri url;
  @override
  final String? message;

  const RollApiUnavailableException(this.url, [this.message]);

  @override
  String toString() => 'RollApiUnavailableException on [$url]: $message';
}

/// Internal server error (500-ish)
class RollApiInternalErrorException implements RollApiException {
  @override
  final Uri url;
  @override
  final String? message;

  const RollApiInternalErrorException(this.url, [this.message]);

  @override
  String toString() => 'RollApiInternalErrorException on [$url]: $message';
}
