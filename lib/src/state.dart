import 'exceptions.dart';

abstract class RollState {
  final String uuid;

  const RollState(this.uuid);

  bool get isSuccess => this is RollStateFinished;

  bool get isWaiting => this is RollStateQueued || this is RollStateRolling;

  bool get isError =>
      this is RollStateErrorExpired || this is RollStateErrorFailed;
}

// Waiting classes

abstract class RollStateWaiting extends RollState {
  final DateTime? eta;

  const RollStateWaiting(String uuid, [this.eta]) : super(uuid);
}

class RollStateQueued extends RollStateWaiting {
  const RollStateQueued(String uuid, [DateTime? eta]) : super(uuid, eta);
}

class RollStateRolling extends RollStateWaiting {
  const RollStateRolling(String uuid, [DateTime? eta]) : super(uuid, eta);
}

// Error classes

abstract class RollStateError extends RollState {
  const RollStateError(String uuid) : super(uuid);
}

class RollStateErrorExpired extends RollStateError {
  const RollStateErrorExpired(String uuid) : super(uuid);
}

class RollStateErrorFailed extends RollStateError {
  final RollApiException exception;

  const RollStateErrorFailed(String uuid, this.exception) : super(uuid);
}

// Success

class RollStateFinished extends RollState {
  final int number;

  const RollStateFinished(String uuid, this.number) : super(uuid);
}
