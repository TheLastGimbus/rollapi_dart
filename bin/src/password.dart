import 'package:rollapi/rollapi.dart';
import 'package:rollapi/utils/crypto.dart';

import 'logging.dart';

/// Generates a random password
///
/// If somethings goes wrong mid-way and API fails too much, it may return
/// *some* password but not the full length - thus, if it will fail at start,
/// it will return 0-length string
///
/// But don't be fooled! It may still throw you some network exceptions!
/// Just on
Future<String> getRandomPassword(
  RollApiClient client, {
  int length = 8,
  String possibleChars = PasswordConverter.lettersLowercase,
}) async {
  final converter =
      PasswordConverter(length: length, possibleCharacters: possibleChars);
  final times = converter.requiredRolls;

  logger.d('Need to roll $times times');

  final rolls = <int>[];
  for (var i = 0; i < times; i++) {
    logger.d('${(i / times * 100).round()}%');
    try {
      rolls.add(await client.getRandomNumber());
    } on RollApiRateLimitException catch (e) {
      logger.d(e);
      if (e.limitReset != null) {
        logger.d('Waiting until: ${e.limitReset}...');
        await Future.delayed(e.limitReset!.difference(DateTime.now()));
      } else {
        logger.d('Waiting 30 seconds...');
        await Future.delayed(Duration(seconds: 30));
      }
      i--;
      continue;
    } on RollApiUnavailableException catch (e) {
      logger.d(e);
      break;
    } on RollApiException catch (e) {
      logger.d(e);
      i--;
      continue;
    }
  }
  return converter.getPassword(rolls);
}
