import 'package:equatable/equatable.dart';
import 'lesson_material_entity.dart';

class LessonEntity extends Equatable {
  final String id;
  final String courseId;
  final String unitId;
  final String title;
  final String description;
  final int order;
  final List<LessonMaterialEntity> materials;
  final String? quizId;
  final bool isPublished;
  final bool isArchived;
  final String? notes;
  final int? bookStartPage;

  const LessonEntity({
    required this.id,
    required this.courseId,
    required this.unitId,
    required this.title,
    required this.description,
    required this.order,
    this.materials = const [],
    this.quizId,
    this.isPublished = true,
    this.isArchived = false,
    this.notes,
    this.bookStartPage,
  });

  LessonEntity copyWith({
    String? id,
    String? courseId,
    String? unitId,
    String? title,
    String? description,
    int? order,
    List<LessonMaterialEntity>? materials,
    String? quizId,
    bool? isPublished,
    bool? isArchived,
    String? notes,
    int? bookStartPage,
  }) {
    return LessonEntity(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      unitId: unitId ?? this.unitId,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      materials: materials ?? this.materials,
      quizId: quizId ?? this.quizId,
      isPublished: isPublished ?? this.isPublished,
      isArchived: isArchived ?? this.isArchived,
      notes: notes ?? this.notes,
      bookStartPage: bookStartPage ?? this.bookStartPage,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    unitId,
    title,
    description,
    order,
    materials,
    quizId,
    isPublished,
    isArchived,
    notes,
    bookStartPage,
  ];
}
