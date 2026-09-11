import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      return await _remoteDataSource.getCurrentUser();
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Stream<UserEntity?> watchAuthState() {
    return _remoteDataSource.watchAuthState();
  }

  @override
  Future<UserEntity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _remoteDataSource.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message, e.code);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw AuthFailure('Sign in failed: $e');
    }
  }

  @override
  Future<UserEntity> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    StudentGrade? grade,
    String? ownerAdminId,
    List<String> enrolledCourseIds = const [],
  }) async {
    try {
      return await _remoteDataSource.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        grade: grade,
        ownerAdminId: ownerAdminId,
        enrolledCourseIds: enrolledCourseIds,
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message, e.code);
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw AuthFailure('Sign up failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure('Sign out failed: $e');
    }
  }

  @override
  Future<void> syncFCMToken(String token) async {
    final user = await getCurrentUser();
    if (user != null) {
      await _remoteDataSource.syncFCMToken(user.id, token);
    }
  }

  @override
  Future<List<Map<String, String>>> fetchCoursesForTeacher({
    required String adminId,
    StudentGrade? grade,
  }) async {
    try {
      return await _remoteDataSource.fetchCoursesForTeacher(
        adminId: adminId,
        grade: grade,
      );
    } on ServerException catch (e) {
      throw ServerFailure(e.message, e.code);
    } catch (e) {
      throw ServerFailure('Failed to fetch teacher courses: $e');
    }
  }
}
