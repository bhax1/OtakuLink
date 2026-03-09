import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  // Here you can insert further business logic, validation, or orchestration.
  FutureEither<UserEntity> call({
    required String identifier,
    required String password,
  }) {
    if (identifier.isEmpty) {
      // Return a validation failure synchronously without hitting the repository
      return Future.value(
        Left(const GeneralFailure('Identifier cannot be empty')),
      );
    }

    return _repository.login(identifier: identifier, password: password);
  }
}
