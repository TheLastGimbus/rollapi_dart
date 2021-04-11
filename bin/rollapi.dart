import 'package:rollapi/rollapi.dart' as roll;

void main(List<String> arguments) async {
  print('TODO: Something interesting here');
  var req = await roll.makeRequest();
  req.stateStream.listen(print);
}
