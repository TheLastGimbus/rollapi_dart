import 'dart:convert';
import 'dart:core';
import 'package:http/http.dart' as http;
import 'dart:async';

import 'src/exceptions.dart';
export 'src/exceptions.dart';

/// Base URL where API lives - must end with the '/'
String API_BASE_URL = 'https://roll.lastgimbus.com/api/';

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
const List<RequestState> errorStates = [
  RequestState.expired,
  RequestState.failed,
];

/// List of states which represent that request is waiting
const List<RequestState> waitingStates = [
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

/// Loop that checks for new states and handles the logic
Stream<MapEntry<RequestState, dynamic>> _stateStream(String uuid) async* {
  yield MapEntry(RequestState.queued, null);
  final infoUrl = Uri.parse('${API_BASE_URL}info/$uuid/');

  DateTime etaDateTime(num epoch) => epoch != null
      ? DateTime.fromMillisecondsSinceEpoch((epoch * 1000).toInt())
      : null;

  var errorCount = 0;
  const maxTries = 6;
  var json = <String, dynamic>{};
  while (true) {
    final delay = etaDateTime(json['eta'] as num)
            ?.difference(DateTime.now())
            ?.inSeconds
            ?.clamp(0, 10) ??
        1;
    await Future.delayed(Duration(seconds: delay.toInt()));

    final infoRes = await http.get(infoUrl);
    if (infoRes.statusCode != 200) {
      if (errorCount < maxTries) {
        errorCount++;
        continue;
      } else {
        yield MapEntry(
          RequestState.failed,
          infoRes.statusCode == 502
              ? ApiUnavailableException(infoRes.body)
              : ApiException(
                  '$infoUrl : ${infoRes.statusCode} : ${infoRes.body}'),
        );
        return;
      }
    }
    // At this point we know it was 200, so we can safely parse the body:
    json = jsonDecode(infoRes.body);
    final state = requestStateFromName(json['status']);
    if (waitingStates.contains(state)) {
      // Normal flow - waiting for result
      // Update the eta - it may change during the waiting
      yield MapEntry(state, etaDateTime(json['eta'] as num));
    } else if (state == RequestState.finished) {
      yield MapEntry(RequestState.finished, json['result'] as int);
      return;
    } else if (errorStates.contains(state)) {
      // If it's already expired then something is not right :/
      yield MapEntry(
        state,
        ApiException('${infoRes.statusCode} : ${infoRes.body}'),
      );
      return;
    } else {
      yield MapEntry(
        RequestState.failed,
        UnimplementedError(
          'Unimplemented request state. This should never happen. '
          'Tell @TheLastGimbus that he broke something',
        ),
      );
      return;
    }
  }
}

/// Makes new requests
///
/// Throws [RateLimitException] if rate limit was exceeded and you need to wait
/// to make new requests
/// Throws an HttpException if it was failed
Future<Request> makeRequest() async {
  final url = Uri.parse(API_BASE_URL + 'roll/');
  final rollRes = await http.get(url);
  if (rollRes.statusCode >= 200 && rollRes.statusCode < 300) {
    final uuid = rollRes.body;
    return Request(uuid, _stateStream(uuid));
  } else if (rollRes.statusCode == 429) {
    final resetEp = rollRes.headers['x-ratelimit-reset'];
    final reset = resetEp != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (num.parse(resetEp) * 1000).toInt(),
          )
        : null;
    throw RateLimitException(rollRes.body, limitReset: reset);
  } else if (rollRes.statusCode == 502) {
    throw ApiUnavailableException(rollRes.body);
  } else {
    throw ApiException('${rollRes.statusCode} : ${rollRes.body}');
  }
}

/// This is *simplest possible* helper function for those who don't want to
/// mess with [stateStream] and [RequestStatus]
///
/// It either returns a number, or throws an Exception in the process. Simple.
Future<int> getSimpleResult() async {
  final req = await makeRequest();
  final result = await req.stateStream.last;
  if (result.key == RequestState.finished) {
    return result.value as int;
  } else if (errorStates.contains(result.key)) {
    throw result.value;
  } else {
    throw ApiException('Request failed :( try again');
  }
}
