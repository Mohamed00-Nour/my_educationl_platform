import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/course_import_schema.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../domain/entities/unit_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../../../notifications/data/services/notification_queue_service.dart';
import '../../../notifications/domain/entities/course_notification_request.dart';

// ================= EVENTS =================
abstract class CourseEvent extends Equatable {
  const CourseEvent();
  @override
  List<Object?> get props => [];
}

class FetchCoursesRequested extends CourseEvent {
  final bool includeArchived;
  const FetchCoursesRequested({this.includeArchived = false});
  @override
  List<Object?> get props => [includeArchived];
}

class StreamCoursesRequested extends CourseEvent {
  final bool includeArchived;
  const StreamCoursesRequested({this.includeArchived = false});
  @override
  List<Object?> get props => [includeArchived];
}

class SelectCourseRequested extends CourseEvent {
  final String courseId;
  const SelectCourseRequested(this.courseId);
  @override
  List<Object?> get props => [courseId];
}

class StreamCourseDetailsRequested extends CourseEvent {
  final String courseId;
  const StreamCourseDetailsRequested(this.courseId);
  @override
  List<Object?> get props => [courseId];
}

class _CoursesStreamUpdated extends CourseEvent {
  final List<CourseEntity> courses;
  const _CoursesStreamUpdated(this.courses);
  @override
  List<Object?> get props => [courses];
}

class _UnitsStreamUpdated extends CourseEvent {
  final List<UnitEntity> units;
  const _UnitsStreamUpdated(this.units);
  @override
  List<Object?> get props => [units];
}

class _LessonsStreamUpdated extends CourseEvent {
  final List<LessonEntity> lessons;
  const _LessonsStreamUpdated(this.lessons);
  @override
  List<Object?> get props => [lessons];
}

class FetchLessonsForUnitRequested extends CourseEvent {
  final String unitId;
  const FetchLessonsForUnitRequested(this.unitId);
  @override
  List<Object?> get props => [unitId];
}

// Course CRUD
class CreateCourseRequested extends CourseEvent {
  final CourseEntity course;
  const CreateCourseRequested(this.course);
  @override
  List<Object?> get props => [course];
}

class UpdateCourseRequested extends CourseEvent {
  final CourseEntity course;
  const UpdateCourseRequested(this.course);
  @override
  List<Object?> get props => [course];
}

class DeleteCourseRequested extends CourseEvent {
  final String courseId;
  const DeleteCourseRequested(this.courseId);
  @override
  List<Object?> get props => [courseId];
}

// Unit CRUD & Reorder
class CreateUnitRequested extends CourseEvent {
  final UnitEntity unit;
  final CourseNotificationRequest? notification;
  const CreateUnitRequested(this.unit, {this.notification});
  @override
  List<Object?> get props => [unit, notification];
}

class UpdateUnitRequested extends CourseEvent {
  final UnitEntity unit;
  const UpdateUnitRequested(this.unit);
  @override
  List<Object?> get props => [unit];
}

class DeleteUnitRequested extends CourseEvent {
  final String unitId;
  final String courseId;
  final bool softDelete;
  const DeleteUnitRequested({
    required this.unitId,
    required this.courseId,
    this.softDelete = true,
  });
  @override
  List<Object?> get props => [unitId, courseId, softDelete];
}

class ReorderUnitsRequested extends CourseEvent {
  final String courseId;
  final List<UnitEntity> units;
  const ReorderUnitsRequested({
    required this.courseId,
    required this.units,
  });
  @override
  List<Object?> get props => [courseId, units];
}

// Lesson CRUD & Reorder
class CreateLessonRequested extends CourseEvent {
  final LessonEntity lesson;
  final CourseNotificationRequest? notification;
  const CreateLessonRequested(this.lesson, {this.notification});
  @override
  List<Object?> get props => [lesson, notification];
}

class UpdateLessonRequested extends CourseEvent {
  final LessonEntity lesson;
  final CourseNotificationRequest? notification;
  const UpdateLessonRequested(this.lesson, {this.notification});
  @override
  List<Object?> get props => [lesson, notification];
}

class DeleteLessonRequested extends CourseEvent {
  final String lessonId;
  final String unitId;
  final String? courseId;
  final bool softDelete;
  const DeleteLessonRequested({
    required this.lessonId,
    required this.unitId,
    this.courseId,
    this.softDelete = true,
  });
  @override
  List<Object?> get props => [lessonId, unitId, courseId, softDelete];
}

class ReorderLessonsRequested extends CourseEvent {
  final String unitId;
  final List<LessonEntity> lessons;
  const ReorderLessonsRequested({
    required this.unitId,
    required this.lessons,
  });
  @override
  List<Object?> get props => [unitId, lessons];
}

// Ministry Seed Import
class ImportMinistrySeedRequested extends CourseEvent {
  final String courseId;
  const ImportMinistrySeedRequested({required this.courseId});
  @override
  List<Object?> get props => [courseId];
}

// Generic JSON Course Import
class ImportCourseFromJsonRequested extends CourseEvent {
  final CourseImportData importData;
  final String ownerAdminId;

  const ImportCourseFromJsonRequested({
    required this.importData,
    required this.ownerAdminId,
  });

  @override
  List<Object?> get props => [importData, ownerAdminId];
}

// ================= STATES =================
abstract class CourseState extends Equatable {
  const CourseState();
  @override
  List<Object?> get props => [];
}

class CourseInitial extends CourseState {}

class CourseLoading extends CourseState {}

class CourseLoaded extends CourseState {
  final List<CourseEntity> courses;
  final CourseEntity? selectedCourse;
  final List<UnitEntity> units;
  final Map<String, List<LessonEntity>> lessonsByUnit;
  final String? successMessage;

  const CourseLoaded({
    required this.courses,
    this.selectedCourse,
    this.units = const [],
    this.lessonsByUnit = const {},
    this.successMessage,
  });

  CourseLoaded copyWith({
    List<CourseEntity>? courses,
    CourseEntity? selectedCourse,
    List<UnitEntity>? units,
    Map<String, List<LessonEntity>>? lessonsByUnit,
    String? successMessage,
    bool clearSuccessMessage = false,
  }) {
    return CourseLoaded(
      courses: courses ?? this.courses,
      selectedCourse: selectedCourse ?? this.selectedCourse,
      units: units ?? this.units,
      lessonsByUnit: lessonsByUnit ?? this.lessonsByUnit,
      successMessage: clearSuccessMessage ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [courses, selectedCourse, units, lessonsByUnit, successMessage];
}

class CourseError extends CourseState {
  final String message;
  const CourseError(this.message);
  @override
  List<Object?> get props => [message];
}

// ================= BLOC =================
class CourseBloc extends Bloc<CourseEvent, CourseState> {
  final CourseRepository _courseRepository;
  final NotificationQueueService? _notificationQueueService;
  StreamSubscription<List<CourseEntity>>? _coursesSubscription;
  StreamSubscription<List<UnitEntity>>? _unitsSubscription;
  StreamSubscription<List<LessonEntity>>? _lessonsSubscription;

  CourseBloc(
    this._courseRepository, {
    NotificationQueueService? notificationQueueService,
  })  : _notificationQueueService = notificationQueueService,
        super(CourseInitial()) {
    on<FetchCoursesRequested>(_onFetchCoursesRequested);
    on<SelectCourseRequested>(_onSelectCourseRequested);
    on<FetchLessonsForUnitRequested>(_onFetchLessonsForUnitRequested);
    on<CreateCourseRequested>(_onCreateCourseRequested);
    on<UpdateCourseRequested>(_onUpdateCourseRequested);
    on<DeleteCourseRequested>(_onDeleteCourseRequested);

    // Real-time stream handlers
    on<StreamCoursesRequested>(_onStreamCoursesRequested);
    on<StreamCourseDetailsRequested>(_onStreamCourseDetailsRequested);
    on<_CoursesStreamUpdated>(_onCoursesStreamUpdated);
    on<_UnitsStreamUpdated>(_onUnitsStreamUpdated);
    on<_LessonsStreamUpdated>(_onLessonsStreamUpdated);

    // Unit handlers
    on<CreateUnitRequested>(_onCreateUnitRequested);
    on<UpdateUnitRequested>(_onUpdateUnitRequested);
    on<DeleteUnitRequested>(_onDeleteUnitRequested);
    on<ReorderUnitsRequested>(_onReorderUnitsRequested);

    // Lesson handlers
    on<CreateLessonRequested>(_onCreateLessonRequested);
    on<UpdateLessonRequested>(_onUpdateLessonRequested);
    on<DeleteLessonRequested>(_onDeleteLessonRequested);
    on<ReorderLessonsRequested>(_onReorderLessonsRequested);

    // Ministry Seeder handler
    on<ImportMinistrySeedRequested>(_onImportMinistrySeedRequested);

    // Generic JSON Importer handler
    on<ImportCourseFromJsonRequested>(_onImportCourseFromJsonRequested);
  }

  Future<void> _onFetchCoursesRequested(
    FetchCoursesRequested event,
    Emitter<CourseState> emit,
  ) async {
    _courseRepository.clearCache();
    emit(CourseLoading());
    try {
      final courses = await _courseRepository.getCourses(
        includeArchived: event.includeArchived,
      );
      emit(CourseLoaded(courses: courses));
    } catch (e) {
      emit(CourseError('Failed to load courses: $e'));
    }
  }

  Future<void> _onStreamCoursesRequested(
    StreamCoursesRequested event,
    Emitter<CourseState> emit,
  ) async {
    await _coursesSubscription?.cancel();
    _coursesSubscription = _courseRepository
        .streamCourses(includeArchived: event.includeArchived)
        .listen(
          (courses) => add(_CoursesStreamUpdated(courses)),
          onError: (_) {},
        );
  }

  Future<void> _onStreamCourseDetailsRequested(
    StreamCourseDetailsRequested event,
    Emitter<CourseState> emit,
  ) async {
    await _unitsSubscription?.cancel();
    await _lessonsSubscription?.cancel();

    _unitsSubscription = _courseRepository
        .streamUnits(event.courseId)
        .listen(
          (units) => add(_UnitsStreamUpdated(units)),
          onError: (_) {},
        );

    _lessonsSubscription = _courseRepository
        .streamLessonsForCourse(event.courseId)
        .listen(
          (lessons) => add(_LessonsStreamUpdated(lessons)),
          onError: (_) {},
        );
  }

  void _onCoursesStreamUpdated(
    _CoursesStreamUpdated event,
    Emitter<CourseState> emit,
  ) {
    if (state is CourseLoaded) {
      final current = state as CourseLoaded;
      CourseEntity? updatedSelected = current.selectedCourse;
      if (updatedSelected != null) {
        final selectedId = updatedSelected.id;
        final match = event.courses.where((c) => c.id == selectedId);
        if (match.isNotEmpty) {
          updatedSelected = match.first;
        }
      }
      emit(current.copyWith(courses: event.courses, selectedCourse: updatedSelected));
    } else {
      emit(CourseLoaded(courses: event.courses));
    }
  }

  void _onUnitsStreamUpdated(
    _UnitsStreamUpdated event,
    Emitter<CourseState> emit,
  ) {
    final current = state is CourseLoaded ? (state as CourseLoaded) : const CourseLoaded(courses: []);
    final updatedMap = Map<String, List<LessonEntity>>.from(current.lessonsByUnit);
    for (final u in event.units) {
      updatedMap.putIfAbsent(u.id, () => []);
    }
    emit(current.copyWith(units: event.units, lessonsByUnit: updatedMap));
  }

  void _onLessonsStreamUpdated(
    _LessonsStreamUpdated event,
    Emitter<CourseState> emit,
  ) {
    final current = state is CourseLoaded ? (state as CourseLoaded) : const CourseLoaded(courses: []);
    final Map<String, List<LessonEntity>> lessonsMap = {};
    for (final lesson in event.lessons) {
      lessonsMap.putIfAbsent(lesson.unitId, () => []).add(lesson);
    }
    for (final unit in current.units) {
      lessonsMap.putIfAbsent(unit.id, () => []);
    }
    emit(current.copyWith(lessonsByUnit: lessonsMap));
  }

  Future<void> _onSelectCourseRequested(
    SelectCourseRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      _courseRepository.clearCache();
      List<CourseEntity> currentCourses = [];
      if (state is CourseLoaded) {
        currentCourses = (state as CourseLoaded).courses;
      } else {
        currentCourses = await _courseRepository.getCourses();
      }

      final matches = currentCourses.where((c) => c.id == event.courseId);
      final selected = matches.isNotEmpty ? matches.first : (currentCourses.isNotEmpty ? currentCourses.first : null);

      emit(CourseLoading());
      final units = await _courseRepository.getUnits(event.courseId);
      final Map<String, List<LessonEntity>> lessonsMap = {};

      for (final unit in units) {
        final lessons = await _courseRepository.getLessons(unit.id);
        lessonsMap[unit.id] = lessons;
      }

      emit(
        CourseLoaded(
          courses: currentCourses,
          selectedCourse: selected,
          units: units,
          lessonsByUnit: lessonsMap,
        ),
      );

      // Start real-time streaming for units and lessons of this course!
      add(StreamCourseDetailsRequested(event.courseId));
    } catch (e) {
      emit(CourseError('Failed to load course details: $e'));
    }
  }

  Future<void> _onFetchLessonsForUnitRequested(
    FetchLessonsForUnitRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        final lessons = await _courseRepository.getLessons(event.unitId);
        final updatedMap = Map<String, List<LessonEntity>>.from(
          current.lessonsByUnit,
        );
        updatedMap[event.unitId] = lessons;
        emit(current.copyWith(lessonsByUnit: updatedMap));
      }
    } catch (e) {
      emit(CourseError('Failed to load lessons: $e'));
    }
  }

  Future<void> _onCreateCourseRequested(
    CreateCourseRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      await _courseRepository.createCourse(event.course);
      add(const FetchCoursesRequested());
    } catch (e) {
      emit(CourseError('Failed to create course: $e'));
    }
  }

  Future<void> _onUpdateCourseRequested(
    UpdateCourseRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      await _courseRepository.updateCourse(event.course);
      add(const FetchCoursesRequested());
    } catch (e) {
      emit(CourseError('فشل تعديل الكورس: $e'));
    }
  }

  Future<void> _onDeleteCourseRequested(
    DeleteCourseRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      await _courseRepository.deleteCourse(event.courseId);
      add(const FetchCoursesRequested());
    } catch (e) {
      emit(CourseError('فشل حذف الكورس: $e'));
    }
  }

  // Unit handlers
  Future<void> _onCreateUnitRequested(
    CreateUnitRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      final createdUnit = await _courseRepository.createUnit(event.unit);
      final notification = event.notification?.withPayload({
        'contentId': createdUnit.id,
      });
      if (notification != null) {
        await _notificationQueueService?.enqueueCourseNotification(notification);
      }
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        final updatedUnits = await _courseRepository.getUnits(event.unit.courseId);
        emit(current.copyWith(
          units: updatedUnits,
          successMessage: 'تمت إضافة الوحدة بنجاح',
        ));
      }
    } catch (e) {
      emit(CourseError('فشل إضافة الوحدة: $e'));
    }
  }

  Future<void> _onUpdateUnitRequested(
    UpdateUnitRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      await _courseRepository.updateUnit(event.unit);
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        final updatedUnits = await _courseRepository.getUnits(event.unit.courseId);
        emit(current.copyWith(
          units: updatedUnits,
          successMessage: 'تم تحديث الوحدة بنجاح',
        ));
      }
    } catch (e) {
      emit(CourseError('فشل تعديل الوحدة: $e'));
    }
  }

  Future<void> _onDeleteUnitRequested(
    DeleteUnitRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      await _courseRepository.deleteUnit(
        event.unitId,
        event.courseId,
        softDelete: event.softDelete,
      );
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        final updatedUnits = await _courseRepository.getUnits(event.courseId);
        final updatedMap = Map<String, List<LessonEntity>>.from(current.lessonsByUnit)
          ..remove(event.unitId);
        emit(current.copyWith(
          units: updatedUnits,
          lessonsByUnit: updatedMap,
          successMessage: 'تم أرشفة/حذف الوحدة بنجاح',
        ));
      }
    } catch (e) {
      emit(CourseError('فشل حذف الوحدة: $e'));
    }
  }

  Future<void> _onReorderUnitsRequested(
    ReorderUnitsRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        emit(current.copyWith(units: event.units));
        await _courseRepository.reorderUnits(event.courseId, event.units);
      }
    } catch (e) {
      emit(CourseError('فشل إعادة ترتيب الوحدات: $e'));
    }
  }

  // Lesson handlers
  Future<void> _onCreateLessonRequested(
    CreateLessonRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      final createdLesson = await _courseRepository.createLesson(event.lesson);
      final notification = event.notification?.withPayload({
        'contentId': createdLesson.id,
      });
      if (notification != null) {
        await _notificationQueueService?.enqueueCourseNotification(notification);
      }
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        final lessons = await _courseRepository.getLessons(event.lesson.unitId);
        final updatedMap = Map<String, List<LessonEntity>>.from(current.lessonsByUnit);
        updatedMap[event.lesson.unitId] = lessons;

        final updatedUnits = await _courseRepository.getUnits(event.lesson.courseId);
        emit(current.copyWith(
          units: updatedUnits,
          lessonsByUnit: updatedMap,
          successMessage: 'تمت إضافة الدرس بنجاح',
        ));
      }
    } catch (e) {
      emit(CourseError('فشل إضافة الدرس: $e'));
    }
  }

  Future<void> _onUpdateLessonRequested(
    UpdateLessonRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      await _courseRepository.updateLesson(event.lesson);
      if (event.notification != null) {
        await _notificationQueueService?.enqueueCourseNotification(
          event.notification!,
        );
      }
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        final lessons = await _courseRepository.getLessons(event.lesson.unitId);
        final updatedMap = Map<String, List<LessonEntity>>.from(current.lessonsByUnit);
        updatedMap[event.lesson.unitId] = lessons;
        emit(current.copyWith(
          lessonsByUnit: updatedMap,
          successMessage: 'تم تحديث الدرس بنجاح',
        ));
      }
    } catch (e) {
      emit(CourseError('فشل تعديل الدرس: $e'));
    }
  }

  Future<void> _onDeleteLessonRequested(
    DeleteLessonRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      await _courseRepository.deleteLesson(
        event.lessonId,
        event.unitId,
        courseId: event.courseId,
        softDelete: event.softDelete,
      );
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        final lessons = await _courseRepository.getLessons(event.unitId);
        final updatedMap = Map<String, List<LessonEntity>>.from(current.lessonsByUnit);
        updatedMap[event.unitId] = lessons;

        List<UnitEntity> updatedUnits = current.units;
        if (event.courseId != null) {
          updatedUnits = await _courseRepository.getUnits(event.courseId!);
        }

        emit(current.copyWith(
          units: updatedUnits,
          lessonsByUnit: updatedMap,
          successMessage: 'تم أرشفة/حذف الدرس بنجاح',
        ));
      }
    } catch (e) {
      emit(CourseError('فشل حذف الدرس: $e'));
    }
  }

  Future<void> _onReorderLessonsRequested(
    ReorderLessonsRequested event,
    Emitter<CourseState> emit,
  ) async {
    try {
      if (state is CourseLoaded) {
        final current = state as CourseLoaded;
        final updatedMap = Map<String, List<LessonEntity>>.from(current.lessonsByUnit);
        updatedMap[event.unitId] = event.lessons;
        emit(current.copyWith(lessonsByUnit: updatedMap));
        await _courseRepository.reorderLessons(event.unitId, event.lessons);
      }
    } catch (e) {
      emit(CourseError('فشل إعادة ترتيب الدروس: $e'));
    }
  }

  // Ministry Seeder handler
  Future<void> _onImportMinistrySeedRequested(
    ImportMinistrySeedRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final result = await _courseRepository.importMinistrySeed(courseId: event.courseId);
      final courses = await _courseRepository.getCourses();
      final matches = courses.where((c) => c.id == event.courseId);
      final selected = matches.isNotEmpty ? matches.first : null;

      final units = await _courseRepository.getUnits(event.courseId);
      final Map<String, List<LessonEntity>> lessonsMap = {};
      for (final unit in units) {
        final lessons = await _courseRepository.getLessons(unit.id);
        lessonsMap[unit.id] = lessons;
      }

      emit(
        CourseLoaded(
          courses: courses,
          selectedCourse: selected,
          units: units,
          lessonsByUnit: lessonsMap,
          successMessage:
              'تم استيراد منهج الوزارة بنجاح (${result.unitsImported} وحدة • ${result.lessonsImported} درس)',
        ),
      );
    } catch (e) {
      emit(CourseError('فشل استيراد منهج الوزارة: $e'));
    }
  }

  Future<void> _onImportCourseFromJsonRequested(
    ImportCourseFromJsonRequested event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    try {
      final createdCourse = await _courseRepository.importCourseFromJson(
        importData: event.importData,
        ownerAdminId: event.ownerAdminId,
      );
      final courses = await _courseRepository.getCourses();
      emit(
        CourseLoaded(
          courses: courses,
          selectedCourse: createdCourse,
          successMessage:
              'تم استيراد كورس "${createdCourse.title}" بنجاح (${event.importData.units.length} وحدة)',
        ),
      );
    } catch (e) {
      emit(CourseError('فشل استيراد الكورس: $e'));
    }
  }

  @override
  Future<void> close() {
    _coursesSubscription?.cancel();
    _unitsSubscription?.cancel();
    _lessonsSubscription?.cancel();
    return super.close();
  }
}
