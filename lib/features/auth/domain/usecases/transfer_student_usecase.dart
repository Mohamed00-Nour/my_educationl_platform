import '../repositories/join_code_repository.dart';

class TransferStudentUseCase {
  final JoinCodeRepository _repository;

  TransferStudentUseCase(this._repository);

  Future<void> call({required String studentId, required String newAdminId}) {
    return _repository.transferStudent(
      studentId: studentId,
      newAdminId: newAdminId,
    );
  }
}
