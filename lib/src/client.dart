import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'state.dart';

class RollApiClient {
  /// Base URL for API - you can change this to your own instance
  final Uri baseUrl;

  /// API password for things like skipping rate limit
  final String? pwd;

  RollApiClient({
    /// Base URL for API - you can change this to your own instance
    ///
    /// Note that it will automatically add a trailing slash if not present
    String baseUrl = 'https://roll.lastgimbus.com/api/',
    this.pwd,
  }) : baseUrl = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');

  Map<String, String> get headers => pwd != null ? {'pwd': pwd!} : {};

  Future<Stream<RollState>> roll() async {
    final url = baseUrl.resolve('roll/');
    final rollRes = await http.get(url, headers: headers);
    if (rollRes.statusCode >= 200 && rollRes.statusCode < 300) {
      final responseStr = rollRes.body;
      if (_isValidUuid(responseStr)) {
        return _stateStream(responseStr);
      } else {
        throw RollApiException(url, '${rollRes.statusCode} : ${rollRes.body}');
      }
    } else if (rollRes.statusCode == 429) {
      final resetEp = rollRes.headers['x-ratelimit-reset'];
      final reset = resetEp != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (num.parse(resetEp) * 1000).toInt(),
            )
          : null;
      throw RollApiRateLimitException(url, rollRes.body, reset);
    } else if (rollRes.statusCode == 502) {
      throw RollApiUnavailableException(url, rollRes.body);
    } else if (rollRes.statusCode >= 500 && rollRes.statusCode < 600) {
      throw RollApiInternalErrorException(
          url, '${rollRes.statusCode} : ${rollRes.body}');
    } else {
      throw RollApiException(url, '${rollRes.statusCode} : ${rollRes.body}');
    }
  }

  Future<int> getRandomNumber() async {
    final req = await roll();
    final result = await req.last;
    if (result is RollStateFinished) {
      return result.number;
    } else if (result is RollStateErrorFailed) {
      throw result.exception;
    } else {
      throw RollApiException(baseUrl, 'Request failed :( try again');
    }
  }

  Stream<RollState> _stateStream(String uuid) async* {
    final infoUrl = baseUrl.resolve('info/$uuid/');

    DateTime etaDateTime(num epoch) =>
        DateTime.fromMillisecondsSinceEpoch((epoch * 1000).toInt());

    var errorCount = 0;
    const maxTries = 6;
    var json = <String, dynamic>{};
    while (true) {
      final epoch = ((json['eta'] as num?) ??
              DateTime.now().millisecondsSinceEpoch / 1000)
          .toInt();
      final num delay =
          etaDateTime(epoch).difference(DateTime.now()).inSeconds.clamp(0, 10);
      await Future.delayed(Duration(seconds: delay.toInt()));

      final infoRes = await http.get(infoUrl, headers: headers);
      if (infoRes.statusCode != 200) {
        if (errorCount < maxTries) {
          errorCount++;
          continue;
        } else {
          yield RollStateErrorFailed(
            uuid,
            infoRes.statusCode == 502
                ? RollApiUnavailableException(infoUrl, infoRes.body)
                : RollApiException(
                    infoUrl, '${infoRes.statusCode} : ${infoRes.body}'),
          );
          return;
        }
      }
      // At this point we know it was 200, so we can safely parse the body:
      json = jsonDecode(infoRes.body);
      // If any of the fields are null then there's something definitely wrong
      // with the API - thus, crush the whole thing
      // "Albo zadziała, albo *totalnie* sie zesra"
      switch (json['status']!) {
        case 'QUEUED':
          yield RollStateQueued(uuid, etaDateTime(json['eta']! as num));
          break;
        case 'RUNNING':
          yield RollStateRolling(uuid, etaDateTime(json['eta']! as num));
          break;
        case 'EXPIRED':
          yield RollStateErrorExpired(uuid);
          return;
        case 'FINISHED':
          yield RollStateFinished(uuid, json['result']! as int);
          return;
        case 'FAILED':
          yield RollStateErrorFailed(
            uuid,
            RollApiException(
                infoUrl, '${infoRes.statusCode} : ${infoRes.body}'),
          );
          return;
        default:
          yield RollStateErrorFailed(
            uuid,
            RollApiException(
              infoUrl,
              'Unimplemented request state "${json['status']}". This should never happen. '
              'Tell @TheLastGimbus that he broke something',
            ),
          );
          return;
      }
    }
  }

  bool _isValidUuid(String uuidStr) {
    // Of course, stolen from internet
    const pattern =
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$';
    // We want only one UUID so multiline=false
    final regex = RegExp(pattern, caseSensitive: false, multiLine: false);
    return regex.hasMatch(uuidStr);
  }
}
