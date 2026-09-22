import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../attendance/domain/repositories/attendance_repository.dart';
import '../../../evaluations/domain/repositories/evaluation_repository.dart';
import '../../../progress/domain/entities/student_progress_summary.dart';
import '../../../quizzes/domain/entities/quiz_entity.dart';
import '../../../quizzes/domain/repositories/quiz_repository.dart';
import '../../domain/entities/parent_report_data.dart';
import '../../domain/services/pdf_report_generator_service.dart';

class ParentReportScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String studentId;
  final String studentName;

  const ParentReportScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ParentReportScreen> createState() => _ParentReportScreenState();
}

class _ParentReportScreenState extends State<ParentReportScreen> {
  String _selectedPeriod = 'شهري';
  DateTimeRange? _customDateRange;
  bool _isGeneratingPdf = false;
  bool _isLoading = true;

  ParentReportData? _reportData;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final initialRange = _customDateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 14)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
      helpText: 'تحديد فترة التقرير المخصصة',
      cancelText: 'إلغاء',
      confirmText: 'تطبيق',
      saveText: 'تطبيق',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Color(0xFF131F24),
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = 'مخصص';
      });
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;
    switch (_selectedPeriod) {
      case 'أسبوعي':
        start = now.subtract(const Duration(days: 7));
        end = now;
        break;
      case 'فصل دراسي':
        start = now.subtract(const Duration(days: 90));
        end = now;
        break;
      case 'مخصص':
        if (_customDateRange != null) {
          start = _customDateRange!.start;
          end = _customDateRange!.end;
        } else {
          start = now.subtract(const Duration(days: 14));
          end = now;
        }
        break;
      case 'شهري':
      default:
        start = now.subtract(const Duration(days: 30));
        end = now;
        break;
    }

    try {
      final attendanceRepo = getIt<AttendanceRepository>();
      final quizRepo = getIt<QuizRepository>();
      final evalRepo = getIt<EvaluationRepository>();

      // Load student grade from Firestore
      StudentGrade? studentGrade;
      try {
        final userDoc =
            await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .doc(widget.studentId)
                .get();
        if (userDoc.exists) {
          final data = userDoc.data();
          studentGrade = StudentGrade.fromString(data?['grade'] as String?);
        }
      } catch (_) {}

      // 1. Fetch real attendance
      final allAttendance = await attendanceRepo.getAttendanceForStudent(
        studentId: widget.studentId,
        courseId: widget.courseId,
      );

      final periodAttendance =
          allAttendance.where((a) {
            final d = DateTime.tryParse(a.sessionDate) ?? a.timestamp;
            return d.isAfter(start.subtract(const Duration(days: 1))) &&
                d.isBefore(end.add(const Duration(days: 1)));
          }).toList();

      final totalSessions = periodAttendance.length;
      final presentCount =
          periodAttendance
              .where((a) => a.status == AttendanceStatus.present)
              .length;
      final absentCount =
          periodAttendance
              .where((a) => a.status == AttendanceStatus.absent)
              .length;
      final lateCount =
          periodAttendance
              .where((a) => a.status == AttendanceStatus.late)
              .length;
      final attendancePercentage =
          totalSessions > 0
              ? double.parse(
                (((presentCount + (lateCount * 0.5)) / totalSessions) * 100.0)
                    .toStringAsFixed(1),
              )
              : 0.0;

      final sessionDetails =
          periodAttendance.map((a) {
            return {
              'date': a.sessionDate,
              'status': a.status.toValue(),
              'note': a.note ?? '',
            };
          }).toList();

      // 2. Fetch real exam & quiz attempts
      final allAttempts = await quizRepo.getAttemptsForStudent(
        widget.studentId,
        courseId: widget.courseId,
      );

      final periodAttempts =
          allAttempts.where((a) {
            return a.submittedAt.isAfter(
                  start.subtract(const Duration(days: 1)),
                ) &&
                a.submittedAt.isBefore(end.add(const Duration(days: 1)));
          }).toList();

      // Pre-fetch course quizzes to display friendly titles
      final Map<String, QuizEntity> quizMap = {};
      try {
        final courseQuizzes = await quizRepo.getQuizzesForCourse(widget.courseId);
        for (final q in courseQuizzes) {
          quizMap[q.id] = q;
        }
      } catch (_) {}

      final List<Map<String, dynamic>> quizzes = [];
      final List<Map<String, dynamic>> exams = [];
      double quizSum = 0;
      double examSum = 0;

      for (final a in periodAttempts) {
        QuizEntity? quiz = quizMap[a.examId];
        if (quiz == null) {
          try {
            quiz = await quizRepo.getQuizById(a.examId);
            if (quiz != null) {
              quizMap[a.examId] = quiz;
            }
          } catch (_) {}
        }

        final isFullExam = quiz?.type == QuizType.fullExam ||
            (quiz == null && a.durationSecondsUsed >= 1800);
        final defaultTitle = isFullExam ? 'امتحان شامل' : 'اختبار قصير';
        final title = (quiz != null && quiz.title.trim().isNotEmpty)
            ? quiz.title.trim()
            : defaultTitle;

        final totalQuestions = a.correctCount + a.incorrectCount;
        final maxMarks = quiz?.totalMarks ??
            (totalQuestions > 0 ? totalQuestions : (a.score > 0 ? a.score : 100));
        final normalizedPercentage =
            PerformanceRating.fromPercentage(a.percentage).percentage;

        if (isFullExam) {
          exams.add({
            'name': title,
            'score': a.score,
            'maxScore': maxMarks,
            'percentage': normalizedPercentage.toStringAsFixed(1),
            'date': DateTimeUtils.toShortDate(a.submittedAt),
            'duration': '${(a.durationSecondsUsed / 60).round()} دقيقة',
          });
          examSum += normalizedPercentage;
        } else {
          quizzes.add({
            'name': title,
            'score': a.score,
            'maxScore': maxMarks,
            'percentage': normalizedPercentage.toStringAsFixed(1),
            'date': DateTimeUtils.toShortDate(a.submittedAt),
          });
          quizSum += normalizedPercentage;
        }
      }

      final quizAverage = quizzes.isNotEmpty ? quizSum / quizzes.length : 0.0;
      final examAverage = exams.isNotEmpty ? examSum / exams.length : 0.0;

      // 3. Fetch real conduct adjustments
      final allAdjustments = await evalRepo.getAdjustmentsForStudent(
        studentId: widget.studentId,
        courseId: widget.courseId,
      );

      final periodAdjustments =
          allAdjustments.where((a) {
            return a.date.isAfter(start.subtract(const Duration(days: 1))) &&
                a.date.isBefore(end.add(const Duration(days: 1)));
          }).toList();

      int totalBonus = 0;
      int totalMinus = 0;
      final List<Map<String, dynamic>> adjustments = [];

      for (final a in periodAdjustments) {
        if (a.isBonus) {
          totalBonus += a.points.abs();
        } else {
          totalMinus += a.points.abs();
        }
        adjustments.add({
          'points': a.points.abs(),
          'type': a.isBonus ? 'bonus' : 'minus',
          'reason': a.reason,
          'date': DateTimeUtils.toShortDate(a.date),
        });
      }

      final netAdjustments = totalBonus - totalMinus;

      final progressSummary = StudentProgressSummary.calculate(
        studentId: widget.studentId,
        studentName: widget.studentName,
        courseId: widget.courseId,
        totalSessions: totalSessions,
        presentSessions: presentCount,
        absentSessions: absentCount,
        lateSessions: lateCount,
        completedQuizzesCount: quizzes.length,
        quizAveragePercentage: quizAverage,
        completedExamsCount: exams.length,
        examAveragePercentage: examAverage,
        totalBonusPoints: totalBonus,
        totalMinusPoints: totalMinus,
      );
      final overallEvaluation = progressSummary.finalCompositeScore;

      final performance = PerformanceRating.fromPercentage(overallEvaluation);
      final remarks =
          'التقدير: ${performance.labelArabic} • ${performance.resultMessageArabic}';

      final teacherNotes =
          totalSessions > 0 ||
                  periodAttempts.isNotEmpty ||
                  periodAdjustments.isNotEmpty
              ? 'ملخص أداء الطالب ${widget.studentName}: بلغت نسبة الحضور $attendancePercentage% من إجمالي $totalSessions حصة. تم تسجيل ${quizzes.length} اختبارات قصيرة و${exams.length} امتحانات شاملة، بمعدل تقييم إجمالي $overallEvaluation%.'
              : 'لا يوجد نشاط دراسي مسجل للطالب ${widget.studentName} خلال هذه الفترة المحددة.';

      if (mounted) {
        setState(() {
          _reportData = ParentReportData(
            studentName: widget.studentName,
            studentGrade: studentGrade,
            courseName: widget.courseName,
            academicYear: '${now.year}-${now.year + 1}',
            reportingPeriod:
                '$_selectedPeriod (${DateTimeUtils.toShortDate(start)} إلى ${DateTimeUtils.toShortDate(end)})',
            startDate: start,
            endDate: end,
            totalSessions: totalSessions,
            presentCount: presentCount,
            absentCount: absentCount,
            lateCount: lateCount,
            attendancePercentage: attendancePercentage,
            sessionDetails: sessionDetails,
            quizzes: quizzes,
            exams: exams,
            quizAverage: progressSummary.quizAveragePercentage,
            examAverage: progressSummary.examAveragePercentage,
            adjustments: adjustments,
            totalBonus: totalBonus,
            totalMinus: totalMinus,
            netAdjustments: netAdjustments,
            teacherNotes: teacherNotes,
            overallEvaluation: overallEvaluation,
            standingRemarks: remarks,
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportAndSharePdf() async {
    if (_reportData == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      await PdfReportGeneratorService.shareOrPrintReport(_reportData!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تصدير التقرير: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير ولي الأمر للمتابعة')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reportData == null
              ? const Center(child: Text('تعذر تحميل بيانات التقرير.'))
              : ResponsiveContent(
                  maxWidth: 880,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Period Selector Strip
                    Row(
                      children: [
                        const Text(
                          'الفترة: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                'أسبوعي',
                                'شهري',
                                'فصل دراسي',
                                'مخصص',
                              ].map((period) {
                                final isSelected = _selectedPeriod == period;
                                final isCustomWithRange =
                                    period == 'مخصص' &&
                                    isSelected &&
                                    _customDateRange != null;
                                final label = isCustomWithRange
                                    ? 'مخصص (${DateTimeUtils.toShortDate(_customDateRange!.start)} - ${DateTimeUtils.toShortDate(_customDateRange!.end)})'
                                    : period;

                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: ChoiceChip(
                                    avatar: period == 'مخصص'
                                        ? Icon(
                                          Icons.date_range_rounded,
                                          size: 16,
                                          color: isSelected
                                              ? const Color(0xFF131F24)
                                              : AppColors.textSecondary,
                                        )
                                        : null,
                                    label: Text(label),
                                    selected: isSelected,
                                    selectedColor: AppColors.primary,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF131F24)
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                    ),
                                    onSelected: (val) {
                                      if (period == 'مخصص') {
                                        _pickCustomDateRange();
                                      } else if (val) {
                                        setState(() {
                                          _selectedPeriod = period;
                                        });
                                        _loadReportData();
                                      }
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Report Header Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withAlpha(20),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            _reportData!.studentName,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_reportData!.studentGrade !=
                                              null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondary
                                                    .withAlpha(20),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _reportData!.studentGrade!
                                                    .toArabicDisplay(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _reportData!.courseName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_reportData!.overallEvaluation}% المجموع',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap:
                                  _selectedPeriod == 'مخصص'
                                      ? _pickCustomDateRange
                                      : null,
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'فترة التقرير: ${_reportData!.reportingPeriod}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    if (_selectedPeriod == 'مخصص')
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit_calendar_rounded,
                                            size: 15,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'تعديل التاريخ',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Attendance Section
                    const _SectionTitle(title: 'سجل الحضور والغياب'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _MiniStat('الحصص', '${_reportData!.totalSessions}'),
                            _MiniStat(
                              'حاضر',
                              '${_reportData!.presentCount}',
                              color: AppColors.present,
                            ),
                            _MiniStat(
                              'غائب',
                              '${_reportData!.absentCount}',
                              color: AppColors.absent,
                            ),
                            _MiniStat(
                              'نسبة الحضور',
                              _reportData!.totalSessions == 0
                                  ? '—'
                                  : '${_reportData!.attendancePercentage}%',
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quizzes & Exams Section
                    const _SectionTitle(title: 'الاختبارات والتقييمات'),
                    if (_reportData!.quizzes.isEmpty &&
                        _reportData!.exams.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'لم يتم رصد اختبارات أو امتحانات خلال هذه الفترة.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      ..._reportData!.quizzes.map(
                        (q) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.quiz_outlined,
                              color: AppColors.secondary,
                            ),
                            title: Text(
                              q['name'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              q['date'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            trailing: Text(
                              '${q['percentage']}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ..._reportData!.exams.map(
                        (e) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: AppColors.primaryLight.withAlpha(12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.assignment_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              e['name'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'امتحان شامل • ${e['date']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            trailing: Text(
                              '${e['percentage']}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Conduct Adjustments
                    const _SectionTitle(
                      title: 'نقاط المشاركة والتفاعل والسلوك',
                    ),
                    if (_reportData!.adjustments.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'لا توجد مكافآت أو خصومات مسجلة خلال هذه الفترة.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._reportData!.adjustments.map((a) {
                        final isBonus = a['type'] == 'bonus';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: StatusBadge(
                              label: '${isBonus ? '+' : ''}${a['points']} نقطة',
                              backgroundColor:
                                  isBonus
                                      ? AppColors.successLight
                                      : AppColors.errorLight,
                              textColor:
                                  isBonus ? AppColors.bonus : AppColors.minus,
                            ),
                            title: Text(
                              a['reason'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              a['date'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),

                    // Teacher Remarks
                    if (_reportData!.teacherNotes != null) ...[
                      const _SectionTitle(title: 'ملاحظات وتوجيهات المعلم'),
                      Card(
                        color: AppColors.warningLight.withAlpha(60),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            _reportData!.teacherNotes!,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Export & Share via WhatsApp Button
                    AppButton(
                      label: 'تصدير التقرير PDF ومشاركته عبر واتساب',
                      icon: Icons.share_rounded,
                      isLoading: _isGeneratingPdf,
                      backgroundColor: AppColors.success,
                      onPressed: _exportAndSharePdf,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
