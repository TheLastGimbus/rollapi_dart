import 'package:logger/logger.dart';

Logger logger = Logger(output: ConsoleOutput());

void initLogger(bool quiet) {
  Logger.level = quiet ? Level.info : Level.verbose;
  logger = Logger(
    filter: ProductionFilter()..level = Logger.level,
    printer: _DumbPrinter(),
    output: ConsoleOutput(),
  );
}

class _DumbPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) => event.message.toString().split('\n');
}