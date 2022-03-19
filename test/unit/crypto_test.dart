import 'dart:math';

import 'package:rollapi/utils/crypto.dart';
import 'package:test/test.dart';

void main() {
  test('password converter', () {
    final pwd = PasswordConverter(
      length: 8,
      possibleCharacters: PasswordConverter.lettersLowercase +
          PasswordConverter.lettersUppercase +
          PasswordConverter.numbers +
          PasswordConverter.specialCharacters,
    );
    getPwd(String nums) => // helper
        pwd.getPassword(nums.split('').map(int.parse).toList());

    expect(pwd.requiredRolls, 19);
    expect(getPwd('1234561234561234561'), 'c^dn3&XO');
    expect(getPwd('2222222222222222222'), 'o3!Q909D');
    expect(getPwd('123456'), 'AT');
    expect(getPwd('66666666666666666666666666666666666666'), 'bio9@Qxx');
    expect(getPwd('3' * Random().nextInt(69)).length <= pwd.length, true);
  });
}
