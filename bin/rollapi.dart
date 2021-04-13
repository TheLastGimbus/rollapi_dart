import 'dart:io';

import 'package:args/args.dart';
import 'package:rollapi/rollapi.dart' as roll;

import 'src/password.dart' as roll_pwd;

void main(List<String> arguments) async {
  print(arguments);
  final parser = ArgParser();
  parser.addOption(
    'url',
    help: 'URL to Roll-API instance',
    defaultsTo: 'https://roll.lastgimbus.com/api/',
  );
  parser.addOption('pwd', help: 'Password for things like skipping rate limit');
  final pwdParser = parser.addCommand('pwd');
  pwdParser.addOption(
    'lenght',
    abbr: 'l',
    help: 'Lenght of the password',
    defaultsTo: '8',
  );
  pwdParser.addFlag(
    'lower',
    help: 'Include lower-case letters',
    defaultsTo: true,
    negatable: true,
  );
  pwdParser.addFlag(
    'upper',
    help: 'Include upper-case letters',
    defaultsTo: false,
    negatable: true,
  );
  pwdParser.addFlag(
    'numbers',
    help: 'Include numbers',
    defaultsTo: false,
    negatable: true,
  );
  pwdParser.addFlag(
    'special',
    help: 'Include special characters: !@#\$%^&*',
    defaultsTo: false,
    negatable: true,
  );
  final args = parser.parse(arguments);

  roll.API_BASE_URL = args['url'];
  if (!roll.API_BASE_URL.endsWith('/')) roll.API_BASE_URL += '/';

  roll.HEADERS['pwd'] = args['pwd'] ?? '';

  switch (args.command?.name) {
    case 'pwd':
      final pwd = args.command!;
      final lenght = int.parse(pwd['lenght']);
      if (lenght < 0) print('Here you go, 0-length password: ');
      if (lenght > 12) {
        print('Trust me, you *DONT* want to wait for this');
        print('If you really want *that long* password, split it in half');
      }
      if (lenght > 18) {
        print("Above 18??? Oh no no no sorry you can't make *THAT LONG*");
        exit(69);
      }
      var chars = '';
      chars += pwd['lower'] ? 'abcdefghijklmnopqrstuvwxyz' : '';
      chars += pwd['upper'] ? 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' : '';
      chars += pwd['numbers'] ? '0123456789' : '';
      chars += pwd['special'] ? '!@#\$%^&*' : '';
      print('Generating random password...');
      final gen = await roll_pwd.getRandomPassword(
          length: lenght, possibleChars: chars);
      print('DONE! Your password: $gen');
      break;
    case null:
      print(await roll.getRandomNumber());
  }
}
