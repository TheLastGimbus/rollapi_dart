import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:rollapi/rollapi.dart';

import 'src/logging.dart';
import 'src/password.dart' as roll_pwd;

late final RollApiClient client;

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
      'password',
      abbr: 'p',
      help: 'API password for things like skipping rate limit',
    )
    ..addOption(
      'pingFrequency',
      abbr: 'f',
      help: 'Minimum ping frequency in milliseconds. '
          'Decreasing it below 200 usually doesn\'t help much, '
          'and can get you in trouble with rate limit.',
      defaultsTo: '200',
    )
    ..addFlag(
      'quiet',
      defaultsTo: false,
      help: 'Keeps output to bare minimum of result, '
          'so it\'s suitable for scripts. The output can still be messy '
          '(exception message for example) if exit code != 0 '
          'so keep that in mind.',
    );

  final args = runner.parse(arguments);

  initLogger(args['quiet']);

  client = RollApiClient(
    baseUrl: args['url'],
    password: args['password'],
    minPingFrequency: Duration(milliseconds: int.parse(args['pingFrequency'])),
  );

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
    argParser.addFlag(
      'failOnIncomplete',
      help: 'Exit with error code if password is not complete',
      defaultsTo: true,
      negatable: true,
    );
  }

  @override
  void run() async {
    final pwd = argResults!;
    final length = int.parse(pwd['length']);
    if (length < 0) logger.v('Here you go, 0-length password: ');
    if (length > 12) {
      logger.v("Trust me, you *DON'T* want to wait for this");
      logger.v('If you really want *that long* password, split it in half');
    }
    if (length > 18) {
      logger.e("Above 18??? Oh no no no sorry you can't make *THAT LONG*");
      exit(69);
    }
    var chars = '';
    chars += pwd['lower'] ? roll_pwd.lettersLowercase : '';
    chars += pwd['upper'] ? roll_pwd.lettersUppercase : '';
    chars += pwd['numbers'] ? roll_pwd.numbers : '';
    chars += pwd['special'] ? roll_pwd.specialCharacters : '';
    logger.d('Generating random password...');
    final gen = await roll_pwd.getRandomPassword(
      client,
      length: length,
      possibleChars: chars,
    );

    if (gen.length < length) {
      logger.v("Couldn't finish your password, but here you go, "
          '${gen.length}/$length characters: ');
    } else {
      logger.d('DONE! Your password: ');
    }
    logger.i(gen);
    if (gen.length < length) exit(3);
  }
}

class RollCommand extends Command {
  @override
  String get description => 'Roll dice one time';

  @override
  String get name => 'roll';

  @override
  void run() async {
    logger.d('Rolling the dice...');
    logger.i(await client.getRandomNumber());
  }
}
