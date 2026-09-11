import '../entities/admin_overview_entity.dart';
import '../entities/user_entity.dart';
import '../repositories/join_code_repository.dart';

class GetAdminsOverviewUseCase {
  final JoinCodeRepository _repository;

  GetAdminsOverviewUseCase(this._repository);

  Future<List<AdminOverviewEntity>> call() {
    return _repository.getAllAdminsOverview();
  }

  Future<List<UserEntity>> getStudentsForAdmin(String adminId) {
    return _repository.getStudentsForAdmin(adminId);
  }
}
