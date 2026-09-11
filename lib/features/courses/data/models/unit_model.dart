import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/unit_entity.dart';

class UnitModel extends UnitEntity {
  const UnitModel({
    required super.id,
    required super.courseId,
    required super.title,
    super.description,
    required super.order,
    super.lessonCount,
    super.isPublished,
    super.isArchived,
    super.bookStartPage,
  });

  factory UnitModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UnitModel(
      id: doc.id,
      courseId: data['courseId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      order: (data['order'] as num?)?.toInt() ?? 0,
      lessonCount: (data['lessonCount'] as num?)?.toInt() ?? 0,
      isPublished: data['isPublished'] as bool? ?? true,
      isArchived: data['isArchived'] as bool? ?? false,
      bookStartPage: (data['bookStartPage'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'title': title,
      'description': description,
      'order': order,
      'lessonCount': lessonCount,
      'isPublished': isPublished,
      'isArchived': isArchived,
      if (bookStartPage != null) 'bookStartPage': bookStartPage,
    };
  }

  factory UnitModel.fromEntity(UnitEntity entity) {
    return UnitModel(
      id: entity.id,
      courseId: entity.courseId,
      title: entity.title,
      description: entity.description,
      order: entity.order,
      lessonCount: entity.lessonCount,
      isPublished: entity.isPublished,
      isArchived: entity.isArchived,
      bookStartPage: entity.bookStartPage,
    );
  }
}
