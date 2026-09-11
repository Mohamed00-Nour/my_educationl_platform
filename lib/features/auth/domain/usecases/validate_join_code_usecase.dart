import '../entities/admin_join_code_entity.dart';
import '../repositories/join_code_repository.dart';

class ValidateJoinCodeUseCase {
  final JoinCodeRepository _repository;

  ValidateJoinCodeUseCase(this._repository);

  Future<AdminJoinCodeEntity> call(String code) async {
    return await _repository.validateJoinCode(code);
  }
}
