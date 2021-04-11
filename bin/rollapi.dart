import 'package:rollapi/rollapi.dart' as roll;

void main(List<String> arguments) async {
  print('Hello world!');
  var req = await roll.makeRequest();
  req.stateStream.listen(print);
}
