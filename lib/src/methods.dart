/// This file contains all nice methods that the end user will use
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'request.dart';
import 'state.dart';

/// Base URL where API lives - must end with the '/'
String API_BASE_URL = 'https://roll.lastgimbus.com/api/';

/// Stream of states for given [uuid] request. Can be useful for example for
/// re-checking state after network loss. Otherwise just use [makeRequest]
///
/// Possible values:
/// - RequestState.queued, DateTime? eta
/// - RequestState.running, DateTime? eta
/// - RequestState.finished, int result
/// - RequestState.expired and RequestState.failed, Exception e - can be:
///
///     - ApiException - generic, something just went wrong, try again
///
///     - ApiUnavailableException - api unavailable, probably maintenance
///
/// This is used by [makeRequest], and is preferred implementation
/// of [Request.stateStream]
Stream<MapEntry<RequestState, dynamic?>> stateStream(String uuid) async* {
  yield MapEntry(RequestState.queued, null);
  final infoUrl = Uri.parse('${API_BASE_URL}info/$uuid/');

  DateTime etaDateTime(num epoch) =>
      DateTime.fromMillisecondsSinceEpoch((epoch * 1000).toInt());

  var errorCount = 0;
  const maxTries = 6;
  var json = <String, dynamic>{};
  while (true) {
    final epoch =
        ((json['eta'] as num?) ?? DateTime.now().millisecondsSinceEpoch / 1000)
            .toInt();
    final num delay =
        etaDateTime(epoch).difference(DateTime.now()).inSeconds.clamp(0, 10);
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
    // If any of the fields are null then there's something definitely wrong
    // with the API - thus, crush the whole thing
    // "Albo zadziała, albo *totalnie* sie zesra"
    final state = requestStateFromName(json['status']!);
    if (requestWaitingStates.contains(state)) {
      // Normal flow - waiting for result
      // Update the eta - it may change during the waiting
      yield MapEntry(state, etaDateTime(json['eta']! as num));
    } else if (state == RequestState.finished) {
      yield MapEntry(RequestState.finished, json['result']! as int);
      return;
    } else if (requestErrorStates.contains(state)) {
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
/// Throws an [ApiUnavailableException] if API is currently unavailable
///
/// Uses [stateStream] under the hood
Future<Request> makeRequest() async {
  final url = Uri.parse(API_BASE_URL + 'roll/');
  final rollRes = await http.get(url);
  if (rollRes.statusCode >= 200 && rollRes.statusCode < 300) {
    final uuid = rollRes.body;
    return Request(uuid, stateStream(uuid));
  } else if (rollRes.statusCode == 429) {
    final resetEp = rollRes.headers['x-ratelimit-reset'];
    final reset = resetEp != null
        ? DateTime.fromMillisecondsSinceEpoch(
            (num.parse(resetEp) * 1000).toInt(),
          )
        : null;
    throw RateLimitException(rollRes.body, reset);
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
///
/// Uses [makeRequest] under the hood
Future<int> getSimpleResult() async {
  final req = await makeRequest();
  final result = await req.stateStream.last;
  if (result.key == RequestState.finished) {
    return result.value as int;
  } else if (requestErrorStates.contains(result.key)) {
    throw result.value;
  } else {
    throw ApiException('Request failed :( try again');
  }
}
