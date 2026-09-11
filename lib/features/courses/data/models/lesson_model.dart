import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/lesson_entity.dart';
import 'lesson_material_model.dart';

class LessonModel extends LessonEntity {
  const LessonModel({
    required super.id,
    required super.courseId,
    required super.unitId,
    required super.title,
    required super.description,
    required super.order,
    super.materials,
    super.quizId,
    super.isPublished,
    super.isArchived,
    super.notes,
    super.bookStartPage,
  });

  factory LessonModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawMaterials = data['materials'] as List<dynamic>? ?? [];

    return LessonModel(
      id: doc.id,
      courseId: data['courseId'] as String? ?? '',
      unitId: data['unitId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      materials:
          rawMaterials
              .map(
                (m) => LessonMaterialModel.fromMap(m as Map<String, dynamic>),
              )
              .toList(),
      quizId: data['quizId'] as String?,
      isPublished: data['isPublished'] as bool? ?? true,
      isArchived: data['isArchived'] as bool? ?? false,
      notes: data['notes'] as String?,
      bookStartPage: (data['bookStartPage'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'unitId': unitId,
      'title': title,
      'description': description,
      'order': order,
      'materials':
          materials
              .map((m) => LessonMaterialModel.fromEntity(m).toMap())
              .toList(),
      'quizId': quizId,
      'isPublished': isPublished,
      'isArchived': isArchived,
      'notes': notes,
      if (bookStartPage != null) 'bookStartPage': bookStartPage,
    };
  }

  factory LessonModel.fromEntity(LessonEntity entity) {
    return LessonModel(
      id: entity.id,
      courseId: entity.courseId,
      unitId: entity.unitId,
      title: entity.title,
      description: entity.description,
      order: entity.order,
      materials: entity.materials,
      quizId: entity.quizId,
      isPublished: entity.isPublished,
      isArchived: entity.isArchived,
      notes: entity.notes,
      bookStartPage: entity.bookStartPage,
    );
  }
}
