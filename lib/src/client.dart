import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exceptions.dart';
import 'state.dart';

class RollApiClient {
  /// Http client used for all requests
  final http.Client httpClient;

  /// Base URL for API - you can change this to your own instance
  final Uri baseUrl;

  /// API password for things like skipping rate limit
  final String? password;

  /// Minimum frequency of pinging API for results when waiting - don't go crazy
  /// cause you might get rate-limited
  final Duration minPingFrequency;

  /// Client for RollAPI
  ///
  /// You can specify RollER instance with [baseUrl] (note that it will
  /// automatically add a trailing slash if not present)
  ///
  /// When you're done with everything and want to exit your code, remember to
  /// call [close()]
  RollApiClient({
    Uri? baseUrl,
    this.password,
    this.minPingFrequency = const Duration(seconds: 10),
    http.Client? httpClient,
  })  : baseUrl = baseUrl != null
            // Ensure leading /
            ? baseUrl.toString().endsWith('/')
                ? baseUrl
                : Uri.parse('$baseUrl/')
            : Uri.parse('https://roll.lastgimbus.com/api/'),
        httpClient = httpClient ?? http.Client();

  /// Headers that will be sent with every request. Currently just [password]
  Map<String, String> get headers => {if (password != null) 'pwd': password!};

  /// Requests a roll and returns it's UUID
  ///
  /// Throws any of [RollApiException]s, or [http.ClientException]s
  Future<String> roll() async {
    final url = getRollUrl();
    final rollRes = await httpClient.get(url, headers: headers);
    if (_httpIsOk(rollRes.statusCode)) {
      if (_isValidUuid(rollRes.body)) {
        return rollRes.body;
      } else {
        throw RollApiException(
            url, 'Invalid UUID! : ${rollRes.statusCode} : ${rollRes.body}');
      }
    } else {
      throw _exceptionFromResponse(rollRes);
    }
  }

  /// <img src="https://raw.githubusercontent.com/TheLastGimbus/rollapi_dart/master/images/xkcd_221_random_number.png" alt="XKCD 221: Chosen by a fair dice roll, guaranteed to be random">
  ///
  /// This is *simplest possible* function, taken straight from XKCD 221,
  /// for those who don't want to mess with stream of states.
  ///
  /// It either returns a number, or throws an Exception in the process. Simple.
  ///
  /// Uses [roll()] and [rollStateStream()] under the hood
  ///
  /// Throws any of [RollApiException]s, or [http.ClientException]s
  Future<int> getRandomNumber() async {
    final req = watchRoll(await roll());
    final result = await req.last;
    if (result is RollStateFinished) {
      return result.number;
    } else {
      throw RollApiException(
          getInfoUrl(result.uuid), 'Request failed :( try again');
    }
  }

  // URL helper functions

  /// Url of image of the dice
  Uri getImageUrl(String uuid) => baseUrl.resolve('image/$uuid/');

  /// Url of image after analysis pre-processing
  Uri getAnalImageUrl(String uuid) => baseUrl.resolve('anal-image/$uuid/');

  /// Url with info about the roll
  Uri getInfoUrl(String uuid) => baseUrl.resolve('info/$uuid/');

  /// Url with pure result of the roll
  Uri getResultUrl(String uuid) => baseUrl.resolve('result/$uuid/');

  /// Url to request a roll
  Uri getRollUrl() => baseUrl.resolve('roll/');

  /// Keeps checking the state of the roll in a loop until it's finished
  ///
  /// If either HTTP or API fails, it retires [maxRetries] times. After that,
  /// it re-throws last exception that caused this ; thus, it can throw either
  /// [RollApiException] (meaning something went bad with *API itself*)
  /// or [http.ClientException] (meaning something went bad with internet)
  Stream<RollState> watchRoll(
    String uuid, {
    int maxRetries = 6,
    Duration retryDelay = const Duration(seconds: 1),
  }) async* {
    final infoUrl = getInfoUrl(uuid);

    // Helper function
    DateTime etaDateTime(num epoch) =>
        DateTime.fromMillisecondsSinceEpoch((epoch * 1000).toInt());

    var errorCount = 0;
    const maxTries = 6;
    var json = <String, dynamic>{};
    while (true) {
      // Fetch eta - if null, set it to now
      final epoch = ((json['eta'] as num?) ??
              DateTime.now().millisecondsSinceEpoch / 1000)
          .toInt();
      // Force the delay to be between 0 and minPingFrequency
      final num delayMs = etaDateTime(epoch)
          .difference(DateTime.now())
          .inMilliseconds
          // If we don't know eta yet (probably first time), you can spam
          .clamp(json['eta'] == null ? 0 : 50, minPingFrequency.inMilliseconds);
      await Future.delayed(Duration(milliseconds: delayMs.toInt()));

      http.Response? infoRes;
      try {
        infoRes = await httpClient.get(infoUrl, headers: headers);
        if (!_httpIsOk(infoRes.statusCode)) {
          throw _exceptionFromResponse(infoRes);
        }
      } catch (e) {
        errorCount++;
        if (errorCount < maxTries) {
          await Future.delayed(retryDelay);
          continue;
        } else {
          rethrow;
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
          yield RollStateErrorFailed(uuid);
          return;
        default:
          throw RollApiException(
            infoUrl,
            'Unimplemented request state [$json]. This should never happen. '
            'Tell @TheLastGimbus that he broke something',
          );
      }
    }
  }

  /// Closes HTTP client etc
  /// Do this when you're done with everything
  void close() async {
    httpClient.close();
  }

  RollApiException _exceptionFromResponse(http.Response res) {
    final url = res.request?.url ?? baseUrl;
    if (res.statusCode == 429) {
      final resetEp = res.headers['x-ratelimit-reset'];
      final reset = resetEp != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (num.parse(resetEp) * 1000).toInt())
          : null;
      return RollApiRateLimitException(url, res.body, reset);
    } else if (res.statusCode == 502) {
      return RollApiUnavailableException(url, res.body);
    } else if (res.statusCode >= 500 && res.statusCode < 600) {
      return RollApiInternalErrorException(
          url, '${res.statusCode} : ${res.body}');
    } else {
      return RollApiException(url, '${res.statusCode} : ${res.body}');
    }
  }

  static bool _isValidUuid(String uuidStr) {
    // Of course, stolen from internet
    const pattern =
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-5][0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$';
    // We want only one UUID so multiline=false
    final regex = RegExp(pattern, caseSensitive: false, multiLine: false);
    return regex.hasMatch(uuidStr);
  }

  static bool _httpIsOk(int code) => code >= 200 && code < 300;
}
