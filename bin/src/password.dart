import 'dart:math';

import 'package:rollapi/rollapi.dart' as roll;

import 'base.dart' as based;

const diceWalls = 6;
const diceCharacters = '123456';

const lettersLowercase = 'abcdefghijklmnopqrstuvwxyz';

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
Future<String> getRandomPassword({
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
  final maxFailures = length * 1;
  var failures = 0;

  var diceString = '';
  for (var i = 0; i < times; i++) {
    print('${(i / times * 100).round()}%');
    try {
      diceString += (await roll.getRandomNumber()).toString();
    } on roll.RateLimitException catch (e) {
      print(e);
      if (e.limitReset != null) {
        print('Waiting until: ${e.limitReset}...');
        await Future.delayed(e.limitReset!.difference(DateTime.now()));
      } else {
        print('Waiting 30 seconds...');
        await Future.delayed(Duration(seconds: 30));
      }
      i--;
      continue;
    } on roll.ApiUnavailableException catch (e) {
      print(e);
      break;
    } on roll.ApiException catch (e) {
      print(e);
      failures++;
      if (failures > maxFailures) break;
      i--;
      continue;
    }
  }
  final dice2pass = based.AnyBase(diceCharacters, possibleChars);
  final pass = dice2pass.convert(diceString);

  if (pass.length > length) {
    return pass.substring(0, length);
  }
  if (pass.length < length) {
    print("Couldn't finish your password, but here you go, "
        '${pass.length}/$length characters');
  }
  return pass;
}
