import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/evaluation_adjustment_model.dart';

abstract class EvaluationRemoteDataSource {
  Future<List<EvaluationAdjustmentModel>> getAdjustmentsForStudent({
    required String studentId,
    required String courseId,
  });

  Future<List<EvaluationAdjustmentModel>> getAdjustmentsForCourse(
    String courseId,
  );

  Future<EvaluationAdjustmentModel> addAdjustment(
    EvaluationAdjustmentModel adjustment,
  );

  Future<void> deleteAdjustment(String id);
}

class EvaluationRemoteDataSourceImpl implements EvaluationRemoteDataSource {
  final FirebaseFirestore _firestore;

  EvaluationRemoteDataSourceImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<EvaluationAdjustmentModel>> getAdjustmentsForStudent({
    required String studentId,
    required String courseId,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.evaluations)
              .where('studentId', isEqualTo: studentId)
              .where('courseId', isEqualTo: courseId)
              .get();

      return snapshot.docs
          .map((d) => EvaluationAdjustmentModel.fromFirestore(d))
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch student adjustments: $e');
    }
  }

  @override
  Future<List<EvaluationAdjustmentModel>> getAdjustmentsForCourse(
    String courseId,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreCollections.evaluations)
              .where('courseId', isEqualTo: courseId)
              .get();

      return snapshot.docs
          .map((d) => EvaluationAdjustmentModel.fromFirestore(d))
          .toList();
    } catch (e) {
      throw ServerException('Failed to fetch course adjustments: $e');
    }
  }

  @override
  Future<EvaluationAdjustmentModel> addAdjustment(
    EvaluationAdjustmentModel adjustment,
  ) async {
    try {
      final docRef =
          _firestore.collection(FirestoreCollections.evaluations).doc();
      final model = EvaluationAdjustmentModel(
        id: docRef.id,
        studentId: adjustment.studentId,
        studentName: adjustment.studentName,
        courseId: adjustment.courseId,
        points: adjustment.points,
        type: adjustment.type,
        reason: adjustment.reason,
        date: adjustment.date,
        addedBy: adjustment.addedBy,
        teacherNotes: adjustment.teacherNotes,
      );

      await docRef.set(model.toMap());
      return model;
    } catch (e) {
      throw ServerException('Failed to save adjustment: $e');
    }
  }

  @override
  Future<void> deleteAdjustment(String id) async {
    try {
      await _firestore
          .collection(FirestoreCollections.evaluations)
          .doc(id)
          .delete();
    } catch (e) {
      throw ServerException('Failed to delete adjustment: $e');
    }
  }
}
