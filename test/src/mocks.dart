import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_test;

const uuid = '93c0182f-ad96-47fc-9b90-876b272cf032';
const etaEpoch = 1112470620;
final eta = DateTime.fromMillisecondsSinceEpoch(etaEpoch * 1000);
const randomNumber = 4;

http_test.MockClient getStandardMockClient() {
  var infoCount = 0;
  return http_test.MockClient((request) async {
    if (request.url.path == '/api/roll/') {
      return http.Response(uuid, 200);
    } else if (request.url.path ==
        '/api/info/93c0182f-ad96-47fc-9b90-876b272cf032/') {
      switch (infoCount++) {
        case 0:
          return http.Response(
              '{"eta":$etaEpoch.0,"queue":0,"result":null,"status":"QUEUED","ttl":0.0}',
              200);
        case 1:
          return http.Response(
              '{"eta":$etaEpoch.0,"queue":0,"result":null,"status":"RUNNING","ttl":0.0}',
              200);
        case 2:
          return http.Response(
              '{"eta":$etaEpoch.0,"queue":0,"result":$randomNumber,"status":"FINISHED","ttl":0.0}',
              200);
        default:
          return http.Response(
              '{"eta":$etaEpoch.0,"queue":0,"result":null,"status":"EXPIRED","ttl":0.0}',
              200);
      }
    } else {
      return http.Response('URL Not found', 404);
    }
  });
}
