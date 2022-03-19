import 'dart:math';

import 'package:any_base/any_base.dart';

/// Crypto stands for cryptography :sunglasses:

/// Helper class for generating random password from dice rolls
class PasswordConverter {
  /// Length of the password
  final int length;

  /// Possible characters which password will be made of
  final String possibleCharacters;
  final AnyBase _dice2pass;

  PasswordConverter({
    this.length = 6,
    this.possibleCharacters = lettersLowercase,
  }) : _dice2pass = AnyBase(diceNumbers, possibleCharacters) {
    if (length < 1) throw ArgumentError('Length must be greater than 0');
    if (possibleCharacters.isEmpty) {
      throw ArgumentError(
          'Possible characters must be at least 1 character long');
    }
  }

  static const diceNumbers = '123456';
  static const lettersLowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const lettersUppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const numbers = '0123456789';
  static const specialCharacters = '!@#\$%^&*';

  /// Number of times we need to roll the dice to get as many possibilities as
  /// there are for our password
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
  int get requiredRolls =>
      (length * _logN(possibleCharacters.length, diceNumbers.length)).ceil();

  String getPassword(List<int> diceRolls) {
    final pwd = _dice2pass.convert(diceRolls.join(''));
    return pwd.substring(0, min(length, pwd.length));
  }

  /// Custom log of N-th level
  num _logN(num x, num n) => log(x) / log(n);
}
