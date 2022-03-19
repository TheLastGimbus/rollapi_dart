import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:rollapi/rollapi.dart';
import 'package:rollapi/utils/crypto.dart';

import 'src/logging.dart';

late final RollApiClient client;
int exitCode = 0;

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
    baseUrl: Uri.parse(args['url']),
    password: args['password'],
    minPingFrequency: Duration(milliseconds: int.parse(args['pingFrequency'])),
  );

  await runner.run(arguments);
  client.close();
  exit(exitCode);
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
    final args = argResults!;
    logger.d('Generating random password...');

    final length = int.parse(args['length']);
    final converter = PasswordConverter(
      length: length,
      possibleCharacters: [
        if (args['lower']) PasswordConverter.lettersLowercase,
        if (args['upper']) PasswordConverter.lettersUppercase,
        if (args['numbers']) PasswordConverter.numbers,
        if (args['special']) PasswordConverter.specialCharacters,
      ].join(''),
    );

    final times = converter.requiredRolls;
    logger.d('Need to roll $times times');
    if (times > 50) {
      logger.v("Trust me, you *DON'T* want to wait for this");
      logger.v('If you really want *that long* password, split it in half');
    }
    if (times > 100) {
      logger.e("Above 100??? Oh no no no sorry you can't make *THAT LONG*");
      exitCode = 69;
      return;
    }

    final rolls = <int>[];
    for (var i = 0; i < times; i++) {
      logger.d('${(i / times * 100).round()}%');
      try {
        rolls.add(await client.getRandomNumber());
      } on RollApiRateLimitException catch (e) {
        logger.d(e);
        final delay = e.limitReset != null
            ? e.limitReset!.difference(DateTime.now())
            : Duration(seconds: 30);
        logger.d('Waiting until: ${DateTime.now().add(delay)}...');
        await Future.delayed(delay);
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

    final gen = converter.getPassword(rolls);
    logger.v(gen.length < length
        ? "Couldn't finish your password, but here you go, "
            "${gen.length}/$length characters: "
        : 'DONE! Your password: ');
    logger.i(gen);
    if (gen.length < length && args['failOnIncomplete']) exitCode = 3;
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
