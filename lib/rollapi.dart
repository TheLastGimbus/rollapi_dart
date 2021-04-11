import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:async';

/// Base URL where API lives - must end with the '/'
String API_BASE_URL = 'https://roll.lastgimbus.com/api/';

enum RequestState {
  queued,
  running,
  expired,
  finished,
  failed,
}

List<RequestState> errorStates = [RequestState.expired, RequestState.failed];
List<RequestState> waitingStates = [RequestState.running, RequestState.queued];

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

class Request {
  final String uuid;
  final Stream<MapEntry<RequestState, dynamic>> stateStream;

  Request(this.uuid, this.stateStream);
}

Stream<MapEntry<RequestState, dynamic>> _stateStream(String uuid) async* {
  yield MapEntry(RequestState.queued, null);
  final infoUrl = Uri.parse('${API_BASE_URL}info/$uuid/');

  var errorCount = 0;
  const tries = 6;
  var json = <String, dynamic>{'result': null};
  while (true) {
    final delay = min(max((json['eta'] as num ?? 0) / 2, 1), 10).toInt();
    await Future.delayed(Duration(seconds: delay));

    final infoRes = await http.get(infoUrl);
    if (infoRes.statusCode != 200) {
      if (errorCount < tries) {
        print('Status code != 200, $errorCount/$tries try');
        errorCount++;
        continue;
      } else {
        yield MapEntry(RequestState.failed, 'Status code != 200');
        return;
      }
    }
    json = jsonDecode(infoRes.body);
    final state = requestStateFromName(json['status']);
    if (waitingStates.contains(state)) {
      // Normal flow - waiting for result
      // Update the eta - it may change during the waiting
      yield MapEntry(
        state,
        DateTime.now().add(Duration(seconds: (json['eta'] as num).toInt())),
      );
    } else if (state == RequestState.finished) {
      yield MapEntry(RequestState.finished, json['result'] as int);
      return;
    } else if (errorStates.contains(state)) {
      // If it's already expired then something is not right :/
      yield MapEntry(state, 'Request was failed: $infoRes');
      return;
    } else {
      yield MapEntry(
        RequestState.failed,
        'Unimplemented request state. This should never happen. '
        'Write to @TheLastGimbus that he broke something',
      );
      return;
    }
  }
}

Future<Request> makeRequest() async {
  final rollRes = await http.get(Uri.parse(API_BASE_URL + 'roll/'));
  if (rollRes.statusCode != 200) {
    throw HttpException("roll/ endpoint didn't return 200");
  }
  final uuid = rollRes.body;
  return Request(uuid, _stateStream(uuid));
}
