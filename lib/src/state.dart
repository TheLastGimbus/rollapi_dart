/// This file contains enums etc to represent the state of the Request

/// State of the request.
/// Whether it's already finished, or waiting in a queue, etc
enum RequestState {
  queued,
  running,
  expired,
  finished,
  failed,
}

/// List of states which represent that request failed
const List<RequestState> requestErrorStates = [
  RequestState.expired,
  RequestState.failed,
];

/// List of states which represent that request is waiting
const List<RequestState> requestWaitingStates = [
  RequestState.running,
  RequestState.queued,
];

// Private map for to/from string conversion
const Map<RequestState, String> _stateMap = {
  RequestState.queued: 'QUEUED',
  RequestState.running: 'RUNNING',
  RequestState.expired: 'EXPIRED',
  RequestState.finished: 'FINISHED',
  RequestState.failed: 'FAILED',
};

RequestState requestStateFromName(String string) =>
    _stateMap.keys.firstWhere((e) => _stateMap[e] == string);

extension on RequestState {
  String toName() => _stateMap[this];
}
