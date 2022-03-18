import 'dart:math';

import 'package:rollapi/rollapi.dart';

import 'base.dart' as based;
import 'logging.dart';

const diceWalls = 6;
const diceCharacters = '123456';

const lettersLowercase = 'abcdefghijklmnopqrstuvwxyz';
const lettersUppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const numbers = '0123456789';
const specialCharacters = '!@#\$%^&*';

/// Custom log of N-th level
num logN(num x, num n) => log(x) / log(n);

/// Generates a random password
///
/// If somethings goes wrong mid-way and API fails too much, it may return
/// *some* password but not the full length - thus, if it will fail at start,
/// it will return 0-length string
///
/// But don't be fooled! It may still throw you some network exceptions!
/// Just on
Future<String> getRandomPassword(RollApiClient client, {
  int length = 8,
  String possibleChars = lettersLowercase,
}) async {
  // Get *all* possible combinations
  final possibleCombinations = pow(possibleChars.length, length).toInt();
  // Number of times we need to roll the dice to get as many possibilities as
  // there are for our password
  // Definition of logarithm is "to what N we need to raise number X to get Y" -
  // our X is number of walls on dice, Y is number of possible combinations, and
  // N will be the number of times we need to roll
  final times = logN(possibleCombinations, diceCharacters.length).ceil();

  var diceString = '';
  for (var i = 0; i < times; i++) {
    logger.d('${(i / times * 100).round()}%');
    try {
      diceString += (await client.getRandomNumber()).toString();
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
    }
  }
  final dice2pass = based.AnyBase(diceCharacters, possibleChars);
  final pass = dice2pass.convert(diceString);

  if (pass.length > length) {
    return pass.substring(0, length);
  }
  return pass;
}
