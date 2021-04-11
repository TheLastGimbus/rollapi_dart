/// This file just contains Request class
import 'state.dart';

/// Class representing a single request. All properties are immutable, and
/// new states are emitted by [stateStream]
class Request {
  /// UUID of the request - can be used to fetch images etc
  final String uuid;

  /// Stream that emits new states
  /// Possible values:
  /// - RequestState.queued, DateTime eta
  /// - RequestState.running, DateTime eta
  /// - RequestState.finished, int result
  /// - RequestState.expired and RequestState.failed, Exception e - can be:
  ///
  ///     - ApiException - generic, something just went wrong, try again
  ///
  ///     - ApiUnavailableException - api unavailable, probably maintenance
  final Stream<MapEntry<RequestState, dynamic>> stateStream;

  Request(this.uuid, this.stateStream);
}
