import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:rollapi/rollapi.dart' as roll;

import 'src/password.dart' as roll_pwd;

void main(List<String> arguments) async {
  final runner = CommandRunner(
    'rollapi',
    'CLI utility for Roll-API - '
        'the *TRUE* random number generator: '
        'https://github.com/TheLastGimbus/Roll-API',
  )
    ..addCommand(RollCommand())
    ..addCommand(PwdCommand());
  runner.argParser
    ..addOption(
      'url',
      help: 'URL to Roll-API instance',
      defaultsTo: 'https://roll.lastgimbus.com/api/',
    )
    ..addOption(
      'pwd',
      help: 'API password for things like skipping rate limit',
    );

  final args = runner.parse(arguments);
  roll.API_BASE_URL = args['url'];
  if (!roll.API_BASE_URL.endsWith('/')) roll.API_BASE_URL += '/';
  roll.HEADERS['pwd'] = args['pwd'] ?? '';

  await runner.run(arguments);
}

class PwdCommand extends Command {
  @override
  String get description => 'Generate random password';

  @override
  String get name => 'pwd';

  PwdCommand() {
    argParser.addOption(
      'length',
      abbr: 'l',
      help: 'Length of the password',
      defaultsTo: '8',
    );
    argParser.addFlag(
      'lower',
      help: 'Include lower-case letters',
      defaultsTo: true,
      negatable: true,
    );
    argParser.addFlag(
      'upper',
      help: 'Include upper-case letters',
      defaultsTo: false,
      negatable: true,
    );
    argParser.addFlag(
      'numbers',
      help: 'Include numbers',
      defaultsTo: false,
      negatable: true,
    );
    argParser.addFlag(
      'special',
      help: 'Include special characters: !@#\$%^&*',
      defaultsTo: false,
      negatable: true,
    );
  }

  @override
  void run() async {
    final pwd = argResults!;
    final length = int.parse(pwd['length']);
    if (length < 0) print('Here you go, 0-length password: ');
    if (length > 12) {
      print("Trust me, you *DON'T* want to wait for this");
      print('If you really want *that long* password, split it in half');
    }
    if (length > 18) {
      print("Above 18??? Oh no no no sorry you can't make *THAT LONG*");
      exit(69);
    }
    var chars = '';
    chars += pwd['lower'] ? 'abcdefghijklmnopqrstuvwxyz' : '';
    chars += pwd['upper'] ? 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' : '';
    chars += pwd['numbers'] ? '0123456789' : '';
    chars += pwd['special'] ? '!@#\$%^&*' : '';
    print('Generating random password...');
    final gen =
        await roll_pwd.getRandomPassword(length: length, possibleChars: chars);
    print('DONE! Your password: $gen');
  }
}

class RollCommand extends Command {
  @override
  String get description => 'Roll dice one time';

  @override
  String get name => 'roll';

  @override
  void run() async {
    print('Rolling the dice...');
    print(await roll.getRandomNumber());
  }
}
