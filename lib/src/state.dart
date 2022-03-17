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
}

// Waiting classes

abstract class RollStateWaiting extends RollState {
  /// Eta when roll is expected to be finished
  final DateTime? eta;

  const RollStateWaiting(String uuid, [this.eta]) : super(uuid);
}

/// Roll is waiting for it's roll in the queue
class RollStateQueued extends RollStateWaiting {
  const RollStateQueued(String uuid, [DateTime? eta]) : super(uuid, eta);
}

/// Roll is rolling right now!!
class RollStateRolling extends RollStateWaiting {
  const RollStateRolling(String uuid, [DateTime? eta]) : super(uuid, eta);
}

// Error classes

abstract class RollStateError extends RollState {
  const RollStateError(String uuid) : super(uuid);
}

/// Roll expired (or never existed at all) - make a new one
class RollStateErrorExpired extends RollStateError {
  const RollStateErrorExpired(String uuid) : super(uuid);
}

/// Roll failed - dice flipped bad or whatever
class RollStateErrorFailed extends RollStateError {
  final RollApiException exception;

  const RollStateErrorFailed(String uuid, this.exception) : super(uuid);
}

// Success

class RollStateFinished extends RollState {
  /// Your precious random number
  final int number;

  const RollStateFinished(String uuid, this.number) : super(uuid);
}
