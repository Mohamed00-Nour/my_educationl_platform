import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/performance_rating.dart';
import '../../auth/domain/entities/user_entity.dart';

class ManagedCourse {
  final String id;
  final String title;
  final StudentGrade? targetGrade;

  const ManagedCourse({
    required this.id,
    required this.title,
    this.targetGrade,
  });
}

class ManagedStudent {
  final String id;
  final String displayName;
  final String email;
  final StudentGrade? grade;
  final String? ownerAdminId;
  final List<String> enrolledCourseIds;
  final DateTime? createdAt;

  const ManagedStudent({
    required this.id,
    required this.displayName,
    required this.email,
    required this.grade,
    required this.ownerAdminId,
    required this.enrolledCourseIds,
    required this.createdAt,
  });

  factory ManagedStudent.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return ManagedStudent(
      id: document.id,
      displayName: (data['displayName'] as String? ?? '').trim(),
      email: (data['email'] as String? ?? '').trim(),
      grade: StudentGrade.fromString(data['grade'] as String?),
      ownerAdminId: data['ownerAdminId'] as String?,
      enrolledCourseIds: List<String>.from(
        data['enrolledCourseIds'] as List? ?? const [],
      ),
      createdAt:
          data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
    );
  }
}

class ManagedExamAttempt {
  final String id;
  final String examId;
  final String courseId;
  final String examTitle;
  final String courseTitle;
  final int score;
  final int totalMarks;
  final double percentage;
  final bool isPassed;
  final int attemptNumber;
  final DateTime submittedAt;

  const ManagedExamAttempt({
    required this.id,
    required this.examId,
    required this.courseId,
    required this.examTitle,
    required this.courseTitle,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    required this.isPassed,
    required this.attemptNumber,
    required this.submittedAt,
  });
}

class StudentManagementException implements Exception {
  final String code;
  final String message;

  const StudentManagementException(this.code, this.message);

  @override
  String toString() => message;
}

class StudentManagementRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StudentManagementRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  Future<List<ManagedStudent>> loadStudents(UserEntity admin) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: AppConstants.roleStudent);

    if (!admin.role.isSuperAdmin) {
      query = query.where('ownerAdminId', isEqualTo: admin.id);
    }

    final snapshot = await query.get();
    final students = snapshot.docs.map(ManagedStudent.fromDocument).toList();
    students.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return students;
  }

  Future<List<ManagedCourse>> loadCourses(UserEntity admin) async {
    final snapshot =
        await _firestore.collection(FirestoreCollections.courses).get();
    final courses = <ManagedCourse>[];

    for (final document in snapshot.docs) {
      final data = document.data();
      final ownerAdminId = data['ownerAdminId'] as String?;
      final isArchived = data['isArchived'] as bool? ?? false;
      if (isArchived) continue;
      if (!admin.role.isSuperAdmin &&
          ownerAdminId != null &&
          ownerAdminId != admin.id) {
        continue;
      }
      courses.add(
        ManagedCourse(
          id: document.id,
          title:
              (data['title'] as String?)?.trim().isNotEmpty == true
                  ? (data['title'] as String).trim()
                  : 'كورس بدون عنوان',
          targetGrade: StudentGrade.fromString(data['targetGrade'] as String?),
        ),
      );
    }

    courses.sort((a, b) => a.title.compareTo(b.title));
    return courses;
  }

  Future<void> updateStudent({
    required ManagedStudent student,
    required String displayName,
    required StudentGrade grade,
    required List<String> enrolledCourseIds,
  }) async {
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) {
      throw const StudentManagementException(
        'unauthenticated',
        'يجب تسجيل الدخول أولاً.',
      );
    }

    final studentRef = _firestore
        .collection(FirestoreCollections.users)
        .doc(student.id);
    try {
      await _firestore.runTransaction((transaction) async {
        final studentSnapshot = await transaction.get(studentRef);
        if (!studentSnapshot.exists) {
          throw const StudentManagementException(
            'not-found',
            'تعذر العثور على الطالب.',
          );
        }

        final data = studentSnapshot.data() ?? const <String, dynamic>{};
        final oldCourseIds = List<String>.from(
          data['enrolledCourseIds'] as List? ?? const [],
        );
        final newCourseIds = enrolledCourseIds.toSet().toList();
        final added =
            newCourseIds
                .where((courseId) => !oldCourseIds.contains(courseId))
                .toList();
        final removed =
            oldCourseIds
                .where((courseId) => !newCourseIds.contains(courseId))
                .toList();
        final changedCourseIds = {...added, ...removed};
        final existingCourseIds = <String>{};

        for (final courseId in changedCourseIds) {
          final courseRef = _firestore
              .collection(FirestoreCollections.courses)
              .doc(courseId);
          final courseSnapshot = await transaction.get(courseRef);
          if (courseSnapshot.exists) existingCourseIds.add(courseId);
        }

        transaction.update(studentRef, {
          'displayName': displayName.trim(),
          'grade': grade.toValue(),
          'enrolledCourseIds': newCourseIds,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': adminId,
        });

        for (final courseId in added.where(existingCourseIds.contains)) {
          transaction.update(
            _firestore.collection(FirestoreCollections.courses).doc(courseId),
            {'studentCount': FieldValue.increment(1)},
          );
        }
        for (final courseId in removed.where(existingCourseIds.contains)) {
          transaction.update(
            _firestore.collection(FirestoreCollections.courses).doc(courseId),
            {'studentCount': FieldValue.increment(-1)},
          );
        }
      });
    } on StudentManagementException {
      rethrow;
    } on FirebaseException catch (error) {
      throw StudentManagementException(
        error.code,
        error.message ?? 'تعذر حفظ بيانات الطالب.',
      );
    }
  }

  Future<void> sendPasswordReset(ManagedStudent student) async {
    if (student.email.trim().isEmpty) {
      throw const StudentManagementException(
        'invalid-argument',
        'لا يوجد بريد تسجيل دخول لهذا الطالب.',
      );
    }
    try {
      await _auth.sendPasswordResetEmail(email: student.email.trim());
    } on FirebaseAuthException catch (error) {
      throw StudentManagementException(
        error.code,
        error.message ?? 'تعذر إرسال رابط تغيير كلمة المرور.',
      );
    }
  }

  Future<List<ManagedExamAttempt>> loadExamAttempts(
    ManagedStudent student,
    List<ManagedCourse> courses,
  ) async {
    final snapshot =
        await _firestore
            .collection(FirestoreCollections.examAttempts)
            .where('studentId', isEqualTo: student.id)
            .get();

    final courseTitles = {
      for (final course in courses) course.id: course.title,
    };
    final examIds =
        snapshot.docs
            .map((document) => document.data()['examId']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
    final quizData = <String, Map<String, dynamic>>{};

    for (final examId in examIds) {
      final quiz =
          await _firestore
              .collection(FirestoreCollections.quizzes)
              .doc(examId)
              .get();
      if (quiz.exists) quizData[examId] = quiz.data()!;
    }

    final attempts =
        snapshot.docs.map((document) {
          final data = document.data();
          final examId = data['examId']?.toString() ?? '';
          final courseId = data['courseId']?.toString() ?? '';
          final quiz = quizData[examId] ?? const <String, dynamic>{};
          final score = (data['score'] as num?)?.toInt() ?? 0;
          final totalMarks = (quiz['totalMarks'] as num?)?.toInt() ?? 0;
          final percentage =
              totalMarks > 0
                  ? score / totalMarks * 100.0
                  : (data['percentage'] as num?)?.toDouble() ?? 0.0;
          final performance = PerformanceRating.fromPercentage(percentage);
          return ManagedExamAttempt(
            id: document.id,
            examId: examId,
            courseId: courseId,
            examTitle:
                (quiz['title'] as String?)?.trim().isNotEmpty == true
                    ? (quiz['title'] as String).trim()
                    : 'اختبار محذوف أو غير متاح',
            courseTitle: courseTitles[courseId] ?? 'كورس غير متاح',
            score: score,
            totalMarks: totalMarks,
            percentage: performance.percentage,
            isPassed: performance.isSuccessful,
            attemptNumber: (data['attemptNumber'] as num?)?.toInt() ?? 1,
            submittedAt:
                data['submittedAt'] is Timestamp
                    ? (data['submittedAt'] as Timestamp).toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0),
          );
        }).toList();

    attempts.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return attempts;
  }

  Future<void> updateExamAttempt({
    required ManagedExamAttempt attempt,
    required int score,
  }) async {
    if (score < 0 || (attempt.totalMarks > 0 && score > attempt.totalMarks)) {
      throw const StudentManagementException(
        'invalid-argument',
        'الدرجة المدخلة غير صحيحة.',
      );
    }
    final performance = PerformanceRating.fromScore(
      score: score,
      totalMarks: attempt.totalMarks,
    );
    try {
      await _firestore
          .collection(FirestoreCollections.examAttempts)
          .doc(attempt.id)
          .update({
            'score': score,
            'percentage': performance.percentage,
            'isPassed': performance.isSuccessful,
            'manuallyEditedAt': FieldValue.serverTimestamp(),
            'manuallyEditedBy': _auth.currentUser?.uid,
          });
    } on FirebaseException catch (error) {
      throw StudentManagementException(
        error.code,
        error.message ?? 'تعذر تعديل نتيجة الاختبار.',
      );
    }
  }

  Future<void> deleteExamAttempt(ManagedExamAttempt attempt) async {
    try {
      await _firestore
          .collection(FirestoreCollections.examAttempts)
          .doc(attempt.id)
          .delete();
    } on FirebaseException catch (error) {
      throw StudentManagementException(
        error.code,
        error.message ?? 'تعذر حذف محاولة الاختبار.',
      );
    }
  }
}
