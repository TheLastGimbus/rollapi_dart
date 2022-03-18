import 'package:rollapi/rollapi.dart';
import 'package:test/test.dart';

import '../src/mocks.dart' as mocks;

void main() {
  test('roll() -> watchRoll()', () async {
    final rollClient = RollApiClient(httpClient: mocks.getStandardMockClient());
    expect(await rollClient.roll(), mocks.uuid);
    expect(
      rollClient.watchRoll(mocks.uuid),
      emitsInOrder([
        RollStateQueued(mocks.uuid, mocks.eta),
        RollStateRolling(mocks.uuid, mocks.eta),
        RollStateFinished(mocks.uuid, mocks.randomNumber),
      ]),
    );
    rollClient.close();
  });
  test('getRandomNumer()', () async {
    final rollClient = RollApiClient(httpClient: mocks.getStandardMockClient());
    expect(await rollClient.getRandomNumber(), mocks.randomNumber);
    rollClient.close();
  });
}
