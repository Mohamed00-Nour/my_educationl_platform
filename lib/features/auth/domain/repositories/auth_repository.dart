import '../../../../core/constants/app_constants.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> getCurrentUser();
  Stream<UserEntity?> watchAuthState();
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<UserEntity> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    StudentGrade? grade,
    String? ownerAdminId,
    List<String> enrolledCourseIds,
  });
  Future<void> signOut();
  Future<void> syncFCMToken(String token);

  /// Fetches courses owned by [adminId], optionally filtered by [grade].
  Future<List<Map<String, String>>> fetchCoursesForTeacher({
    required String adminId,
    StudentGrade? grade,
  });
}
