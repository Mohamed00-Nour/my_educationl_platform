import '../../domain/entities/lesson_material_entity.dart';

class LessonMaterialModel extends LessonMaterialEntity {
  const LessonMaterialModel({
    required super.id,
    required super.title,
    required super.type,
    required super.url,
    super.notes,
    super.startPage,
    super.endPage,
  });

  factory LessonMaterialModel.fromMap(Map<String, dynamic> map) {
    return LessonMaterialModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      type: CourseMaterialType.fromString(map['type'] as String?),
      url: map['url'] as String? ?? '',
      notes: map['notes'] as String?,
      startPage: (map['startPage'] as num?)?.toInt(),
      endPage: (map['endPage'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type.toValue(),
      'url': url,
      'notes': notes,
      if (startPage != null) 'startPage': startPage,
      if (endPage != null) 'endPage': endPage,
    };
  }

  factory LessonMaterialModel.fromEntity(LessonMaterialEntity entity) {
    return LessonMaterialModel(
      id: entity.id,
      title: entity.title,
      type: entity.type,
      url: entity.url,
      notes: entity.notes,
      startPage: entity.startPage,
      endPage: entity.endPage,
    );
  }
}
