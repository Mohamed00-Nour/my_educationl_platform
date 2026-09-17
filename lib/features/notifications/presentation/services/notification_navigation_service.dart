import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/url_service.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../courses/domain/entities/course_entity.dart';
import '../../../courses/domain/entities/lesson_entity.dart';
import '../../../courses/domain/entities/lesson_material_entity.dart';
import '../../../courses/domain/repositories/course_repository.dart';
import '../../../courses/domain/services/material_type_resolver.dart';
import '../../../courses/presentation/screens/course_detail_screen.dart';
import '../../../courses/presentation/screens/html_viewer_screen.dart';
import '../../../courses/presentation/screens/lesson_detail_screen.dart';
import '../../../courses/presentation/screens/pdf_viewer_screen.dart';
import '../../../courses/presentation/screens/video_player_screen.dart';
import '../../../quizzes/domain/repositories/quiz_repository.dart';
import '../../../quizzes/presentation/screens/exam_taking_screen.dart';
import '../../../quizzes/presentation/widgets/start_code_dialog.dart';
import '../screens/notifications_screen.dart';

class NotificationNavigationException implements Exception {
  final String message;

  const NotificationNavigationException(this.message);

  @override
  String toString() => message;
}

/// Resolves an FCM data payload to an authorized in-app destination.
class NotificationNavigationService {
  final CourseRepository _courseRepository;
  final QuizRepository _quizRepository;

  const NotificationNavigationService({
    required CourseRepository courseRepository,
    required QuizRepository quizRepository,
  }) : _courseRepository = courseRepository,
       _quizRepository = quizRepository;

  Future<void> open({
    required NavigatorState navigator,
    required UserEntity user,
    required Map<String, dynamic> payload,
  }) async {
    final contentType = _value(payload, 'contentType').toLowerCase();
    final contentId = _value(payload, 'contentId');
    final courseId =
        _value(payload, 'courseId').isNotEmpty
            ? _value(payload, 'courseId')
            : (_value(payload, 'targetType') == 'course'
                ? _value(payload, 'targetId')
                : '');

    switch (contentType) {
      case 'quiz':
      case 'exam':
        await _openQuiz(navigator: navigator, user: user, quizId: contentId);
        return;
      case 'lesson':
        await _openLesson(
          navigator: navigator,
          user: user,
          lessonId: contentId,
        );
        return;
      case 'material':
        await _openMaterial(
          navigator: navigator,
          user: user,
          courseId: courseId,
          lessonId: _value(payload, 'lessonId'),
          materialId: contentId,
        );
        return;
      case 'unit':
      case 'course':
        await _openCourse(navigator: navigator, user: user, courseId: courseId);
        return;
      default:
        if (courseId.isNotEmpty) {
          await _openCourse(
            navigator: navigator,
            user: user,
            courseId: courseId,
          );
          return;
        }
        unawaited(
          navigator.push(
            MaterialPageRoute(builder: (_) => NotificationsScreen(user: user)),
          ),
        );
    }
  }

  Future<void> _openCourse({
    required NavigatorState navigator,
    required UserEntity user,
    required String courseId,
  }) async {
    if (courseId.isEmpty) {
      throw const NotificationNavigationException(
        'الإشعار لا يحتوي على معرّف الكورس.',
      );
    }
    final course = await _loadAllowedCourse(courseId, user);
    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(course: course, user: user),
        ),
      ),
    );
  }

  Future<void> _openLesson({
    required NavigatorState navigator,
    required UserEntity user,
    required String lessonId,
  }) async {
    if (lessonId.isEmpty) {
      throw const NotificationNavigationException(
        'الإشعار لا يحتوي على معرّف الدرس.',
      );
    }
    final lesson = await _courseRepository.getLessonById(lessonId);
    if (lesson == null || lesson.isArchived || !lesson.isPublished) {
      throw const NotificationNavigationException('هذا الدرس غير متاح حالياً.');
    }
    await _loadAllowedCourse(lesson.courseId, user);
    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder: (_) => LessonDetailScreen(lesson: lesson, user: user),
        ),
      ),
    );
  }

  Future<void> _openQuiz({
    required NavigatorState navigator,
    required UserEntity user,
    required String quizId,
  }) async {
    if (quizId.isEmpty) {
      throw const NotificationNavigationException(
        'الإشعار لا يحتوي على معرّف الاختبار.',
      );
    }
    final quiz = await _quizRepository.getQuizById(quizId);
    if (quiz == null || !quiz.isPublished) {
      throw const NotificationNavigationException(
        'هذا الاختبار غير متاح حالياً.',
      );
    }
    await _loadAllowedCourse(quiz.courseId, user);

    if (user.isAdmin) {
      if (quiz.lessonId != null && quiz.lessonId!.isNotEmpty) {
        await _openLesson(
          navigator: navigator,
          user: user,
          lessonId: quiz.lessonId!,
        );
      } else {
        await _openCourse(
          navigator: navigator,
          user: user,
          courseId: quiz.courseId,
        );
      }
      return;
    }

    if (!quiz.isAvailableNow) {
      throw const NotificationNavigationException(
        'هذا الاختبار غير متاح في الوقت الحالي.',
      );
    }
    if (!navigator.mounted) return;
    final startCode = await StartCodeDialog.show(navigator.context, quiz);
    if (startCode == null) return;
    unawaited(
      navigator.push(
        MaterialPageRoute(
          builder:
              (_) => ExamTakingScreen(
                quizId: quiz.id,
                user: user,
                startCode: startCode,
              ),
        ),
      ),
    );
  }

  Future<void> _openMaterial({
    required NavigatorState navigator,
    required UserEntity user,
    required String courseId,
    required String lessonId,
    required String materialId,
  }) async {
    if (materialId.isEmpty) {
      throw const NotificationNavigationException(
        'الإشعار لا يحتوي على معرّف المادة التعليمية.',
      );
    }

    LessonEntity? lesson;
    if (lessonId.isNotEmpty) {
      lesson = await _courseRepository.getLessonById(lessonId);
    } else if (courseId.isNotEmpty) {
      final units = await _courseRepository.getUnits(courseId);
      final lessonsByUnit = await Future.wait(
        units.map((unit) => _courseRepository.getLessons(unit.id)),
      );
      for (final candidate in lessonsByUnit.expand((items) => items)) {
        if (candidate.materials.any((item) => item.id == materialId)) {
          lesson = candidate;
          break;
        }
      }
    }

    if (lesson == null || lesson.isArchived || !lesson.isPublished) {
      throw const NotificationNavigationException(
        'تعذر العثور على الدرس المرتبط بهذا الملحق.',
      );
    }
    await _loadAllowedCourse(lesson.courseId, user);

    final matches = lesson.materials.where((item) => item.id == materialId);
    if (matches.isEmpty) {
      throw const NotificationNavigationException(
        'هذه المادة التعليمية لم تعد متاحة.',
      );
    }
    final material = matches.first;
    unawaited(
      navigator.push(
        MaterialPageRoute(builder: (_) => _materialScreen(material)),
      ),
    );
  }

  Widget _materialScreen(LessonMaterialEntity material) {
    if (UrlService.isGoogleHostedFileUrl(material.url)) {
      return HtmlViewerScreen(material: material);
    }
    final detected = MaterialTypeResolver.detect(material.url);
    if (detected == CourseMaterialType.pdf) {
      return PdfViewerScreen(material: material);
    }
    if (detected == CourseMaterialType.video) {
      return VideoPlayerScreen(material: material);
    }
    return HtmlViewerScreen(material: material);
  }

  Future<CourseEntity> _loadAllowedCourse(
    String courseId,
    UserEntity user,
  ) async {
    if (user.isStudent && !user.enrolledCourseIds.contains(courseId)) {
      throw const NotificationNavigationException(
        'هذا المحتوى لا ينتمي إلى كورساتك المسجلة.',
      );
    }
    final course = await _courseRepository.getCourseById(courseId);
    if (course == null || course.isArchived) {
      throw const NotificationNavigationException(
        'هذا الكورس غير متاح حالياً.',
      );
    }
    if (user.isAdmin &&
        !user.isSuperAdmin &&
        course.ownerAdminId != null &&
        course.ownerAdminId != user.id) {
      throw const NotificationNavigationException(
        'لا يمكنك فتح محتوى تابع لمعلم آخر.',
      );
    }
    return course;
  }

  String _value(Map<String, dynamic> payload, String key) =>
      payload[key]?.toString().trim() ?? '';
}
