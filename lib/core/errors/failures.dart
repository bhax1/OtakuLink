import 'package:fpdart/fpdart.dart';

/// Base Failure class for standardizing error structures
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Represents failures caused by server/API issues
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Represents failures caused by local caching/storage issues
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Represents a general validation or generic issue
class GeneralFailure extends Failure {
  const GeneralFailure(super.message);
}

/// Shorthand type alias for returning either a Failure or Success data
typedef FutureEither<T> = Future<Either<Failure, T>>;
typedef FutureEitherVoid = FutureEither<Unit>;
