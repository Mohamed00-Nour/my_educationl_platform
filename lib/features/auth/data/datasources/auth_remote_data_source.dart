import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel?> getCurrentUser();
  Stream<UserModel?> watchAuthState();
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    StudentGrade? grade,
    String? ownerAdminId,
    List<String> enrolledCourseIds,
  });
  Future<void> signOut();
  Future<void> syncFCMToken(String uid, String token);

  /// Returns courses belonging to [adminId], optionally filtered by [grade].
  Future<List<Map<String, String>>> fetchCoursesForTeacher({
    required String adminId,
    StudentGrade? grade,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRemoteDataSourceImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserModel?> getCurrentUser() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return null;

    try {
      final doc =
          await _firestore
              .collection(FirestoreCollections.users)
              .doc(currentUser.uid)
              .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      } else {
        // Keep a partially-created Auth account signed in so the signup flow
        // can safely finish its profile after the user enters the teacher code.
        return null;
      }
    } catch (e) {
      throw ServerException('Failed to retrieve user profile: $e');
    }
  }

  @override
  Stream<UserModel?> watchAuthState() {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      try {
        final doc =
            await _firestore
                .collection(FirestoreCollections.users)
                .doc(user.uid)
                .get();
        if (doc.exists) {
          return UserModel.fromFirestore(doc);
        }
        return null;
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthException('No user returned from Firebase');
      }

      final doc =
          await _firestore
              .collection(FirestoreCollections.users)
              .doc(user.uid)
              .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      } else {
        throw const AuthException(
          'Account setup is incomplete. Choose Create new account and submit the same email and password to finish registration.',
          'incomplete-profile',
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthErrorMessage(e), e.code);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Sign in failed: $e');
    }
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    StudentGrade? grade,
    String? ownerAdminId,
    List<String> enrolledCourseIds = const [],
  }) async {
    User? newlyCreatedUser;
    try {
      final normalizedEmail = email.trim();
      final currentUser = _firebaseAuth.currentUser;
      User? user;

      // A previous app version could create the Auth account and then fail the
      // Firestore batch. If that partial account is still signed in, complete
      // its profile instead of returning "email already in use" forever.
      if (currentUser != null &&
          currentUser.email?.toLowerCase() == normalizedEmail.toLowerCase()) {
        final profile =
            await _firestore
                .collection(FirestoreCollections.users)
                .doc(currentUser.uid)
                .get();
        await currentUser.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: normalizedEmail,
            password: password,
          ),
        );
        if (profile.exists) {
          return UserModel.fromFirestore(profile);
        }
        user = currentUser;
      }

      if (user == null) {
        try {
          final credential = await _firebaseAuth.createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
          user = credential.user;
          newlyCreatedUser = user;
        } on FirebaseAuthException catch (error) {
          if (error.code != 'email-already-in-use') rethrow;

          // Recover an orphaned Auth account even after an app restart or on a
          // different session. A complete account still reports the normal
          // email-already-in-use error.
          final credential = await _firebaseAuth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
          final existingUser = credential.user;
          if (existingUser == null) rethrow;

          final profile =
              await _firestore
                  .collection(FirestoreCollections.users)
                  .doc(existingUser.uid)
                  .get();
          if (profile.exists) rethrow;
          user = existingUser;
        }
      }

      if (user == null) {
        throw const AuthException('User creation failed');
      }

      await user.updateDisplayName(displayName.trim());

      final userModel = UserModel(
        id: user.uid,
        email: normalizedEmail,
        displayName: displayName.trim(),
        role: role,
        grade: grade,
        ownerAdminId: ownerAdminId,
        enrolledCourseIds: enrolledCourseIds,
        createdAt: DateTime.now(),
      );

      // Use a batch to atomically create the user doc and update course student counts.
      final batch = _firestore.batch();

      batch.set(
        _firestore.collection(FirestoreCollections.users).doc(user.uid),
        userModel.toMap(),
      );

      for (final courseId in enrolledCourseIds) {
        batch.update(
          _firestore.collection(FirestoreCollections.courses).doc(courseId),
          {'studentCount': FieldValue.increment(1)},
        );
      }

      await batch.commit();

      return userModel;
    } on FirebaseAuthException catch (e) {
      await _deletePartialAccount(newlyCreatedUser);
      throw AuthException(_mapFirebaseAuthErrorMessage(e), e.code);
    } on AuthException {
      await _deletePartialAccount(newlyCreatedUser);
      rethrow;
    } catch (e) {
      await _deletePartialAccount(newlyCreatedUser);
      throw ServerException('Sign up failed: $e');
    }
  }

  Future<void> _deletePartialAccount(User? user) async {
    if (user == null) return;
    try {
      await user.delete();
    } catch (_) {
      // Preserve the original registration error. A still-signed-in partial
      // account can be completed by the recovery path on the next attempt.
    }
  }

  @override
  Future<List<Map<String, String>>> fetchCoursesForTeacher({
    required String adminId,
    StudentGrade? grade,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(FirestoreCollections.courses)
          .where('ownerAdminId', isEqualTo: adminId)
          .where('isArchived', isEqualTo: false);

      if (grade != null) {
        query = query.where('targetGrade', isEqualTo: grade.toValue());
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title':
              (data['title'] as String?)?.trim().isNotEmpty == true
                  ? (data['title'] as String)
                  : 'كورس بدون عنوان',
        };
      }).toList();
    } on FirebaseException catch (e) {
      throw ServerException(
        'Failed to fetch teacher courses: ${e.message ?? e.code}',
        e.code,
      );
    } catch (e) {
      throw ServerException('Failed to fetch teacher courses: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw ServerException('Sign out failed: $e');
    }
  }

  @override
  Future<void> syncFCMToken(String uid, String token) async {
    try {
      await _firestore.collection(FirestoreCollections.users).doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical token update failure
    }
  }

  String _mapFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email. Please try again.';
      case 'email-already-in-use':
        return 'This email address is already registered.';
      case 'invalid-email':
        return 'The email address is formatted incorrectly.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been deactivated. Please contact your instructor.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few moments and try again.';
      default:
        return e.message ??
            'Authentication failed. Please verify your credentials.';
    }
  }
}
