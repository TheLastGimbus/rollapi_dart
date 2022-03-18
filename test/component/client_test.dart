import 'package:rollapi/rollapi.dart';
import 'package:test/test.dart';

import '../src/mocks.dart' as mocks;

void main() {
  group('with successfull roll', () {
    test('roll() -> watchRoll()', () async {
      final rollClient = RollApiClient(httpClient: mocks.getStandardClient());
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
      final rollClient = RollApiClient(httpClient: mocks.getStandardClient());
      expect(await rollClient.getRandomNumber(), mocks.randomNumber);
      rollClient.close();
    });
    test('watchRoll() on expired UUID', () {
      final rollClient = RollApiClient(httpClient: mocks.getStandardClient());
      final randomUuid = '6f8b6b71-b931-425a-b6f2-2f1478a64d11';
      expect(
        rollClient.watchRoll(randomUuid),
        emitsInOrder([RollStateErrorExpired(randomUuid)]),
      );
    });
  });
  group('with failed roll', () {
    test('roll() -> watchRoll()', () async {
      final rollClient =
          RollApiClient(httpClient: mocks.getStandardClient(failRoll: true));
      expect(await rollClient.roll(), mocks.uuid);
      expect(
        rollClient.watchRoll(mocks.uuid),
        emitsInOrder([
          RollStateQueued(mocks.uuid, mocks.eta),
          RollStateRolling(mocks.uuid, mocks.eta),
          RollStateErrorFailed(mocks.uuid),
        ]),
      );
      rollClient.close();
    });
    test('getRandomNumer()', () async {
      final rollClient =
          RollApiClient(httpClient: mocks.getStandardClient(failRoll: true));
      expect(
        () async => await rollClient.getRandomNumber(),
        throwsA(isA<RollApiException>()),
      );
      rollClient.close();
    });
  });
  group('with API unavailable', () {
    test('roll() -> watchRoll()', () async {
      final rollClient =
          RollApiClient(httpClient: mocks.getUnavailableClient());
      expect(
        () async => await rollClient.roll(),
        throwsA(isA<RollApiUnavailableException>()),
      );
      expect(
        rollClient.watchRoll(mocks.uuid),
        emitsError(isA<RollApiUnavailableException>()),
      );
      rollClient.close();
    });
    test('getRandomNumer()', () async {
      final rollClient =
          RollApiClient(httpClient: mocks.getUnavailableClient());
      expect(
        () async => await rollClient.getRandomNumber(),
        throwsA(isA<RollApiException>()),
      );
      rollClient.close();
    });
  });
}
