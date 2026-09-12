import 'package:flutter/material.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../progress/presentation/screens/student_progress_screen.dart';
import '../../../quizzes/domain/entities/exam_attempt_entity.dart';
import '../../../quizzes/domain/entities/local_attempt_entity.dart';
import '../../../quizzes/domain/entities/quiz_entity.dart';
import '../../../quizzes/domain/repositories/quiz_repository.dart';
import '../../../quizzes/presentation/screens/exam_result_screen.dart';
import '../../../quizzes/presentation/screens/exam_taking_screen.dart';
import '../../../quizzes/presentation/widgets/start_code_dialog.dart';
import 'course_list_screen.dart';

import '../../../../core/widgets/responsive_layout.dart';

class StudentMainScreen extends StatefulWidget {
  final UserEntity user;
  const StudentMainScreen({super.key, required this.user});

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activeCourseId =
        widget.user.enrolledCourseIds.isNotEmpty
            ? widget.user.enrolledCourseIds.first
            : '';

    final List<Widget> pages = [
      CourseListScreen(user: widget.user),
      _StudentExamsTab(user: widget.user),
      StudentProgressScreen(
        studentId: widget.user.id,
        studentName: widget.user.displayName,
        courseId: activeCourseId,
      ),
      NotificationsScreen(user: widget.user, courseId: activeCourseId),
    ];

    final isMobile = context.isMobile;

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.menu_book_rounded),
        selectedIcon: Icon(
          Icons.menu_book_rounded,
          color: AppColors.primary,
        ),
        label: 'كورساتي',
      ),
      NavigationDestination(
        icon: Icon(Icons.assignment_rounded),
        selectedIcon: Icon(
          Icons.assignment_rounded,
          color: AppColors.secondary,
        ),
        label: 'الامتحانات',
      ),
      NavigationDestination(
        icon: Icon(Icons.emoji_events_rounded),
        selectedIcon: Icon(
          Icons.emoji_events_rounded,
          color: AppColors.warning,
        ),
        label: 'مستواي',
      ),
      NavigationDestination(
        icon: Icon(Icons.notifications_rounded),
        selectedIcon: Icon(
          Icons.notifications_rounded,
          color: AppColors.accent,
        ),
        label: 'التنبيهات',
      ),
    ];

    if (!isMobile) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primary.withAlpha(35),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book_rounded),
                  selectedIcon: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                  ),
                  label: Text('كورساتي', style: TextStyle(fontFamily: 'Cairo')),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_rounded),
                  selectedIcon: Icon(
                    Icons.assignment_rounded,
                    color: AppColors.secondary,
                  ),
                  label: Text('الامتحانات', style: TextStyle(fontFamily: 'Cairo')),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.emoji_events_rounded),
                  selectedIcon: Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.warning,
                  ),
                  label: Text('مستواي', style: TextStyle(fontFamily: 'Cairo')),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.notifications_rounded),
                  selectedIcon: Icon(
                    Icons.notifications_rounded,
                    color: AppColors.accent,
                  ),
                  label: Text('التنبيهات', style: TextStyle(fontFamily: 'Cairo')),
                ),
              ],
            ),
            const VerticalDivider(
              thickness: 1,
              width: 1,
              color: AppColors.border,
            ),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 2)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          indicatorColor: AppColors.primary.withAlpha(35),
          destinations: destinations,
        ),
      ),
    );
  }
}

class _StudentExamsTab extends StatefulWidget {
  final UserEntity user;
  const _StudentExamsTab({required this.user});

  @override
  State<_StudentExamsTab> createState() => _StudentExamsTabState();
}

class _StudentExamsTabState extends State<_StudentExamsTab> {
  final Set<String> _downloadedQuizIds = {};
  final Set<String> _downloadingQuizIds = {};
  final Map<String, List<ExamAttemptEntity>> _attemptsByQuizId = {};
  bool _isLoadingCache = true;
  bool _isAutoDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = getIt<QuizRepository>();
    final cached = await repo.getAllCachedQuizzes();

    final activeCourseId = widget.user.enrolledCourseIds.isNotEmpty
        ? widget.user.enrolledCourseIds.first
        : '';

    List<ExamAttemptEntity> attempts = [];
    try {
      attempts = await repo.getAttemptsForStudent(
        widget.user.id,
        courseId: activeCourseId,
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _downloadedQuizIds.clear();
        for (final q in cached) {
          _downloadedQuizIds.add(q.id);
        }
        _attemptsByQuizId.clear();
        for (final a in attempts) {
          _attemptsByQuizId.putIfAbsent(a.examId, () => []).add(a);
        }
        _isLoadingCache = false;
      });
    }
  }

  void _checkAndAutoDownload(List<QuizEntity> quizzes) {
    if (_isAutoDownloading) return;
    final toDownload = quizzes.where(
      (q) =>
          !_downloadedQuizIds.contains(q.id) &&
          !_downloadingQuizIds.contains(q.id),
    ).toList();

    if (toDownload.isEmpty) return;

    _isAutoDownloading = true;
    Future.microtask(() async {
      final repo = getIt<QuizRepository>();
      for (final quiz in toDownload) {
        if (!mounted) break;
        setState(() {
          _downloadingQuizIds.add(quiz.id);
        });
        try {
          final completeQuiz = await repo.getQuizById(quiz.id) ?? quiz;
          await repo.cacheQuizForOffline(completeQuiz);
          if (mounted) {
            setState(() {
              _downloadedQuizIds.add(quiz.id);
              _downloadingQuizIds.remove(quiz.id);
            });
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _downloadingQuizIds.remove(quiz.id);
            });
          }
        }
      }
      _isAutoDownloading = false;
    });
  }

  Future<void> _downloadForOffline(QuizEntity quiz) async {
    if (_downloadingQuizIds.contains(quiz.id)) return;
    setState(() {
      _downloadingQuizIds.add(quiz.id);
    });

    try {
      final repo = getIt<QuizRepository>();
      final completeQuiz = await repo.getQuizById(quiz.id) ?? quiz;
      await repo.cacheQuizForOffline(completeQuiz);
      if (mounted) {
        setState(() {
          _downloadedQuizIds.add(quiz.id);
          _downloadingQuizIds.remove(quiz.id);
        });
        final hasCode = completeQuiz.requireStartCode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasCode
                  ? 'تم تحميل "${completeQuiz.title}" ورمز البدء بنجاح! تم التحميل وجاهز للبدء بدون إنترنت.'
                  : 'تم تحميل وتجهيز "${completeQuiz.title}" بنجاح! تم التحميل وجاهز للبدء.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingQuizIds.remove(quiz.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الاختبار: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startQuizOrExam(QuizEntity quiz) async {
    final repo = getIt<QuizRepository>();
    final effectiveQuiz = await repo.getQuizById(quiz.id) ?? quiz;

    // Check if the student has already passed or consumed allowed attempts
    final attempts = _attemptsByQuizId[quiz.id] ?? [];
    final hasPassed = attempts.any((a) => a.isPassed);
    final hasConsumedRetries = attempts.length >= effectiveQuiz.maxAttempts;
    final isDeadlinePassed =
        effectiveQuiz.availableUntil != null &&
        DateTime.now().isAfter(effectiveQuiz.availableUntil!);

    if (hasPassed ||
        (attempts.isNotEmpty && (hasConsumedRetries || isDeadlinePassed))) {
      final latest = (List<ExamAttemptEntity>.from(attempts)
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt))).first;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamResultScreen(
            attempt: latest,
            quiz: effectiveQuiz,
          ),
        ),
      );
      _loadData();
      return;
    }

    // 1. Check if there is an active local attempt in progress (survives restart)
    final activeAttempt = await repo.loadActiveAttemptLocally(
      effectiveQuiz.id,
      widget.user.id,
    );
    if (activeAttempt != null &&
        activeAttempt.status == AttemptSyncStatus.inProgress) {
      // Resume directly without requiring Start Code again!
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  ExamTakingScreen(quizId: effectiveQuiz.id, user: widget.user),
        ),
      );
      _loadData();
      return;
    }

    // 2. Check Start Code if required (validated offline)
    String? validatedCode;
    if (effectiveQuiz.requireStartCode) {
      if (!mounted) return;
      final enteredCode = await StartCodeDialog.show(context, effectiveQuiz);
      if (enteredCode == null) return;
      validatedCode = enteredCode;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ExamTakingScreen(
              quizId: effectiveQuiz.id,
              user: widget.user,
              startCode: validatedCode,
            ),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final activeCourseId =
        widget.user.enrolledCourseIds.isNotEmpty
            ? widget.user.enrolledCourseIds.first
            : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاختبارات والامتحانات المتاحة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              setState(() {});
              _loadData();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<QuizEntity>>(
        future: getIt<QuizRepository>().getQuizzesForCourse(activeCourseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _isLoadingCache) {
            return const Center(child: CircularProgressIndicator());
          }

          final quizzes =
              (snapshot.data ?? []).where((q) => q.isPublished).toList();
          if (quizzes.isEmpty) {
            return const EmptyStateView(
              icon: Icons.assignment_outlined,
              title: 'لا توجد اختبارات متاحة',
              message: 'لم يتم جدولة أي اختبارات أو امتحانات في الوقت الحالي.',
            );
          }

          // Auto-download all published quizzes when student is online
          _checkAndAutoDownload(quizzes);

          return ResponsiveContent(
            maxWidth: 860,
            child: ListView.builder(
              padding: context.screenPadding,
              itemCount: quizzes.length,
              itemBuilder: (context, index) {
                final quiz = quizzes[index];
                final isOfflineReady = _downloadedQuizIds.contains(quiz.id);
                final isDownloading = _downloadingQuizIds.contains(quiz.id);
                final isExam = quiz.isFullExam;

                final attempts = _attemptsByQuizId[quiz.id] ?? [];
                final hasPassed = attempts.any((a) => a.isPassed);
                final hasConsumedRetries =
                    attempts.length >= quiz.maxAttempts;
                final isDeadlinePassed =
                    quiz.availableUntil != null &&
                    DateTime.now().isAfter(quiz.availableUntil!);
                final isCompleted =
                    hasPassed ||
                    (attempts.isNotEmpty &&
                        (hasConsumedRetries || isDeadlinePassed));

                final latestAttempt =
                    attempts.isNotEmpty
                        ? (List<ExamAttemptEntity>.from(attempts)
                          ..sort(
                            (a, b) => b.submittedAt.compareTo(a.submittedAt),
                          )).first
                        : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.border, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      if (isCompleted && latestAttempt != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ExamResultScreen(
                                  attempt: latestAttempt,
                                  quiz: quiz,
                                ),
                          ),
                        ).then((_) => _loadData());
                      } else {
                        _startQuizOrExam(quiz);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isExam
                                          ? AppColors.accent
                                          : AppColors.primary)
                                      .withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isExam
                                      ? Icons.military_tech_outlined
                                      : Icons.assignment_outlined,
                                  color:
                                      isExam
                                          ? AppColors.accent
                                          : AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quiz.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${isExam ? 'امتحان شامل' : 'اختبار قصير'} • ${quiz.durationMinutes} دقيقة • ${quiz.questions.length} سؤال',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isCompleted && !isOfflineReady) ...[
                                const SizedBox(width: 8),
                                if (isDownloading)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    child: const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(
                                      Icons.download_for_offline_outlined,
                                      color: AppColors.primary,
                                    ),
                                    tooltip:
                                        'تحميل الاختبار ورمز البدء للعمل بدون إنترنت',
                                    onPressed: () => _downloadForOffline(quiz),
                                  ),
                              ],
                            ],
                          ),
                          // Badges row (Start code + Status badges)
                          if (quiz.requireStartCode ||
                              isCompleted ||
                              isOfflineReady ||
                              isDownloading) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (quiz.requireStartCode)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.warning.withAlpha(90),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock_outline,
                                          size: 12,
                                          color: AppColors.warning,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'رمز سري',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.warning,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (isCompleted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withAlpha(25),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.success.withAlpha(90),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          size: 14,
                                          color: AppColors.success,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          hasPassed
                                              ? 'تم الإجتياز بنجاح'
                                              : 'تم الإجتياز',
                                          style: const TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                        if (latestAttempt != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '• ${latestAttempt.score}/${quiz.totalMarks}',
                                            style: const TextStyle(
                                              color: AppColors.success,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  )
                                else if (isOfflineReady)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withAlpha(25),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.success.withAlpha(90),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: AppColors.success,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'تم التحميل وجاهز للبدء',
                                          style: TextStyle(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (isDownloading)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.primary.withAlpha(70),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'جاري التجهيز والتحميل...',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (quiz.description.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              quiz.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (isCompleted && latestAttempt != null)
                                Expanded(
                                  child: AppButton(
                                    label: 'عرض تفاصيل ونتيجة الاختبار',
                                    icon: Icons.visibility_outlined,
                                    backgroundColor:
                                        AppColors.surfaceVariant,
                                    textColor: AppColors.primaryLight,
                                    bevelHeight: 3,
                                    height: 46,
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => ExamResultScreen(
                                                attempt: latestAttempt,
                                                quiz: quiz,
                                              ),
                                        ),
                                      );
                                      _loadData();
                                    },
                                  ),
                                )
                              else ...[
                                Expanded(
                                  child: AppButton(
                                    label:
                                        isExam
                                            ? 'بدء الامتحان الآن'
                                            : 'بدء الاختبار الآن',
                                    icon: Icons.play_arrow_rounded,
                                    height: 46,
                                    onPressed:
                                        () => _startQuizOrExam(quiz),
                                  ),
                                ),
                                if (!isOfflineReady && !isDownloading) ...[
                                  const SizedBox(width: 10),
                                  IconButton.filledTonal(
                                    icon: const Icon(
                                      Icons.download_rounded,
                                    ),
                                    tooltip: 'تحميل للعمل بدون إنترنت',
                                    onPressed:
                                        () => _downloadForOffline(quiz),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
