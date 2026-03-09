import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  FutureEither<UserEntity> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final userDto = await remoteDataSource.login(identifier, password);
      // Map DTO to Entity before returning
      return Right(userDto.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(GeneralFailure('An unexpected error occurrred.'));
    }
  }

  @override
  FutureEitherVoid logout() async {
    try {
      await remoteDataSource.logout();
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  FutureEither<UserEntity?> getCurrentUser() async {
    try {
      final userDto = await remoteDataSource.getCurrentUser();
      return Right(userDto?.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  FutureEither<UserEntity> signUp({
    required String email,
    required String username,
    required String password,
    String? displayName,
  }) async {
    try {
      final userDto = await remoteDataSource.signUp(
        email,
        username,
        password,
        displayName: displayName,
      );
      return Right(userDto.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(GeneralFailure(e.toString()));
    }
  }

  @override
  FutureEitherVoid sendPasswordReset(String email) async {
    try {
      await remoteDataSource.sendPasswordReset(email);
      return const Right(unit);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(GeneralFailure(e.toString()));
    }
  }
}
