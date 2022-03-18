import 'package:test/test.dart';

import '../../bin/src/base.dart' as based;
import '../../bin/src/password.dart' as pwd;

void main() {
  test('test_base', () {
    const possibleChars = pwd.lettersLowercase +
        pwd.lettersUppercase +
        pwd.numbers +
        pwd.specialCharacters;
    final dice2pass = based.AnyBase(pwd.diceCharacters, possibleChars);
    expect(dice2pass.convert('123456'), 'AT');
    expect(dice2pass.convert('654321'), 'jj8');
    expect(dice2pass.convert('123456123456'), 'dRWp3');
    expect(dice2pass.convert('654321654321'), 'brcReY');
  });
}
