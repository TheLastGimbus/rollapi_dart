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
Future<String> getRandomPassword(
  RollApiClient client, {
  int length = 8,
  String possibleChars = lettersLowercase,
}) async {
  // Number of times we need to roll the dice to get as many possibilities as
  // there are for our password
  // Definition of logarithm is "to what N we need to raise number X to get Y" -
  // our X is number of walls on dice, Y is number of possible combinations, and
  // N will be the number of times we need to roll
  //
  // BIG NOTE: Because Y would be very, very big
  // (lower+upper+numbers+special=70 ^ (for example) 16 = very big nuber)
  // - we would need to use BigInt or something (which wouldn't work with log())
  //
  // // DEPRECATED: Get *all* possible combinations:
  // // final possibleCombinations = BigInt.from(possibleChars.length).pow(length);
  //
  // Luckily, I used [Photomath](https://photomath.com/) to optimize those two
  // operations into one and here is what came out:
  final times =
      (length * logN(possibleChars.length, diceCharacters.length)).ceil();

  logger.d('Need to roll $times times');

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
    } on RollApiException catch (e) {
      logger.d(e);
      i--;
      continue;
    }
  }
  final dice2pass = based.AnyBase(diceCharacters, possibleChars);
  final pass = dice2pass.convert(diceString);

  if (pass.length > length) {
    return pass.substring(0, length);
  }
  return pass;
}
