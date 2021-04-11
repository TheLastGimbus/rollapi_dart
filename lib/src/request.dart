/// This file just contains Request class
import 'state.dart';

/// Class representing a single request. All properties are immutable, and
/// new states are emitted by [stateStream]
class Request {
  /// UUID of the request - can be used to fetch images etc
  final String uuid;

  /// Stream that emits new states - preferably, from [stateStream] function
  /// - look at it's documentation for possible values
  final Stream<MapEntry<RequestState, dynamic>> stateStream;

  Request(this.uuid, this.stateStream);
}
