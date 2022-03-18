/// Here are all classes that hold state and data of the request
///
/// The intention is to keep any heavy logic from here and keep just necessary
/// data
///
/// Any helper functions like getting image of successful roll should be left
/// to the client

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

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RollState &&
            runtimeType == other.runtimeType &&
            uuid == other.uuid);
  }
}

// Waiting classes

/// We are waiting for our roll to happen
abstract class RollStateWaiting extends RollState {
  /// Eta when roll is expected to be finished
  final DateTime? eta;

  const RollStateWaiting(String uuid, [this.eta]) : super(uuid);

  @override
  String toString() => 'RollStateWaiting($uuid, $eta)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RollStateWaiting &&
            runtimeType == other.runtimeType &&
            uuid == other.uuid &&
            eta == other.eta);
  }
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

/// Those states mean that something *with the roll* failed. E.g. it was either
/// expired or failed internally
///
/// IT DOES NOT mean that API is unavailable or your internet doesn't work.
/// It means that RollER was successfully reached, and told us something is bad
/// with our roll
abstract class RollStateError extends RollState {
  const RollStateError(String uuid) : super(uuid);

  @override
  String toString() => 'RollStateError($uuid)';
}

/// Roll expired (or never existed at all)
class RollStateErrorExpired extends RollStateError {
  const RollStateErrorExpired(String uuid) : super(uuid);

  @override
  String toString() => 'RollStateErrorExpired($uuid)';
}

/// Roll failed - dice flipped bad or something
class RollStateErrorFailed extends RollStateError {
  const RollStateErrorFailed(String uuid) : super(uuid);

  @override
  String toString() => 'RollStateErrorFailed($uuid)';
}

// Success

/// Roll was successfully finished, and here is the result
class RollStateFinished extends RollState {
  /// Your precious random number
  final int number;

  const RollStateFinished(String uuid, this.number) : super(uuid);

  @override
  String toString() => 'RollStateFinished($uuid, $number)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RollStateFinished &&
            runtimeType == other.runtimeType &&
            uuid == other.uuid &&
            number == other.number);
  }
}
