import 'package:equatable/equatable.dart';

class UnitEntity extends Equatable {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int order;
  final int lessonCount;
  final bool isPublished;
  final bool isArchived;
  final int? bookStartPage;

  const UnitEntity({
    required this.id,
    required this.courseId,
    required this.title,
    this.description = '',
    required this.order,
    this.lessonCount = 0,
    this.isPublished = true,
    this.isArchived = false,
    this.bookStartPage,
  });

  UnitEntity copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? order,
    int? lessonCount,
    bool? isPublished,
    bool? isArchived,
    int? bookStartPage,
  }) {
    return UnitEntity(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      lessonCount: lessonCount ?? this.lessonCount,
      isPublished: isPublished ?? this.isPublished,
      isArchived: isArchived ?? this.isArchived,
      bookStartPage: bookStartPage ?? this.bookStartPage,
    );
  }

  @override
  List<Object?> get props => [
    id,
    courseId,
    title,
    description,
    order,
    lessonCount,
    isPublished,
    isArchived,
    bookStartPage,
  ];
}
