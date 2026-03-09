import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/user_entity.dart';

part 'user_dto.freezed.dart';
part 'user_dto.g.dart';

@freezed
class UserDto with _$UserDto {
  const UserDto._();

  const factory UserDto({
    required String id,
    required String email,
    String? username,
    String? displayName,
    String? emailConfirmedAt,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);

  /// Helper to convert the data transfer object to a pure domain entity
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      username: username,
      displayName: displayName,
      isEmailVerified: emailConfirmedAt != null && emailConfirmedAt!.isNotEmpty,
    );
  }
}
