/// Here are all classes that hold state and data of the request
///
/// The intention is to keep any heavy logic from here and keep just necessary
/// data
///
/// Any helper functions like getting image of successful roll should be left
/// to the client
import 'exceptions.dart';

abstract class RollState {
  /// UUID of the roll
  final String uuid;

  const RollState(this.uuid);

  bool get isSuccess => this is RollStateFinished;

  bool get isWaiting => this is RollStateQueued || this is RollStateRolling;

  bool get isError =>
      this is RollStateErrorExpired || this is RollStateErrorFailed;

  // Actually, I don't know if adding those to abstract classes makes sense :D
  @override
  String toString() => 'RollState($uuid)';
}

// Waiting classes

abstract class RollStateWaiting extends RollState {
  /// Eta when roll is expected to be finished
  final DateTime? eta;

  const RollStateWaiting(String uuid, [this.eta]) : super(uuid);

  @override
  String toString() => 'RollStateWaiting($uuid, $eta)';
}

/// Roll is waiting for it's roll in the queue
class RollStateQueued extends RollStateWaiting {
  const RollStateQueued(String uuid, [DateTime? eta]) : super(uuid, eta);

  @override
  String toString() => 'RollStateQueued($uuid, $eta)';
}

/// Roll is rolling right now!!
class RollStateRolling extends RollStateWaiting {
  const RollStateRolling(String uuid, [DateTime? eta]) : super(uuid, eta);

  @override
  String toString() => 'RollStateRolling($uuid, $eta)';
}

// Error classes

abstract class RollStateError extends RollState {
  const RollStateError(String uuid) : super(uuid);

  @override
  String toString() => 'RollStateError($uuid)';
}

/// Roll expired (or never existed at all) - make a new one
class RollStateErrorExpired extends RollStateError {
  const RollStateErrorExpired(String uuid) : super(uuid);

  @override
  String toString() => 'RollStateErrorExpired($uuid)';
}

/// Roll failed - dice flipped bad or API unavailable or something
class RollStateErrorFailed extends RollStateError {
  /// This exception can tell you if API is unavailable ([RollApiUnavailableException])
  final RollApiException exception;

  const RollStateErrorFailed(String uuid, this.exception) : super(uuid);

  @override
  String toString() => 'RollStateErrorFailed($uuid, $exception)';
}

// Success

class RollStateFinished extends RollState {
  /// Your precious random number
  final int number;

  const RollStateFinished(String uuid, this.number) : super(uuid);

  @override
  String toString() => 'RollStateFinished($uuid, $number)';
}
