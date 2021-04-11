import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:async';

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
  /// - RequestState.expired, String errorMessage
  /// - RequestState.failed, String errorMessage
  /// - RequestState.finished, int result
  final Stream<MapEntry<RequestState, dynamic>> stateStream;

  Request(this.uuid, this.stateStream);
}

/// Represents that rate limit was exceeded and you need to wait to make
/// new requests
class RateLimitException implements Exception {
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
class ApiUnavailableException implements Exception {
  final String message;

  ApiUnavailableException({this.message});

  @override
  String toString() => 'ApiUnavailableException: $message';
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
          'Status code != 200: ${infoRes.statusCode} : ${infoRes.body}',
        );
        return;
      }
    }
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
        'Request was failed: ${infoRes.statusCode} : ${infoRes.body}',
      );
      return;
    } else {
      yield MapEntry(
        RequestState.failed,
        'Unimplemented request state. This should never happen. '
        'Tell @TheLastGimbus that he broke something',
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
    throw ApiUnavailableException(message: rollRes.body);
  } else {
    throw HttpException('${rollRes.statusCode} : ${rollRes.body}', uri: url);
  }
}
