import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../data/student_management_repository.dart';

Color _managedAttemptColor(ManagedExamAttempt attempt) {
  final performance = PerformanceRating.fromPercentage(attempt.percentage);
  return AppColors.forPerformance(performance.band);
}

class StudentExamManagementScreen extends StatefulWidget {
  final ManagedStudent student;
  final List<ManagedCourse> courses;
  final StudentManagementRepository repository;

  const StudentExamManagementScreen({
    super.key,
    required this.student,
    required this.courses,
    required this.repository,
  });

  @override
  State<StudentExamManagementScreen> createState() =>
      _StudentExamManagementScreenState();
}

class _StudentExamManagementScreenState
    extends State<StudentExamManagementScreen> {
  bool _loading = true;
  String? _error;
  List<ManagedExamAttempt> _attempts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final attempts = await widget.repository.loadExamAttempts(
        widget.student,
        widget.courses,
      );
      if (mounted) {
        setState(() {
          _attempts = attempts;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل نتائج الاختبارات. $error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _editAttempt(ManagedExamAttempt attempt) async {
    final changed = await showDialog<bool>(
      context: context,
      builder:
          (_) => _EditAttemptDialog(
            attempt: attempt,
            repository: widget.repository,
          ),
    );
    if (changed == true) await _load();
  }

  Future<void> _deleteAttempt(ManagedExamAttempt attempt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('إعادة إتاحة الاختبار للطالب؟'),
            content: Text(
              'سيتم حذف محاولة "${attempt.examTitle}" ودرجتها نهائياً، '
              'وبذلك يستطيع الطالب إجراء محاولة جديدة وفق إعدادات الاختبار.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.restart_alt),
                label: const Text('حذف المحاولة'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.deleteExamAttempt(attempt);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف المحاولة ويمكن للطالب المحاولة مجدداً.'),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    } on StudentManagementException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed = _attempts.where((attempt) => attempt.isPassed).length;
    final average =
        _attempts.isEmpty
            ? 0.0
            : _attempts.fold<double>(
                  0,
                  (sum, attempt) => sum + attempt.percentage,
                ) /
                _attempts.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('درجات واختبارات ${widget.student.displayName}'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ResponsiveContent(
          maxWidth: 1000,
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        Icons.error_outline,
                        size: 52,
                        color: AppColors.error.withAlpha(180),
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                    ],
                  )
                  : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: context.screenPadding,
                    children: [
                      Row(
                        children: [
                          _SummaryMetric(
                            label: 'المحاولات',
                            value: '${_attempts.length}',
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          _SummaryMetric(
                            label: 'ناجح',
                            value: '$passed',
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          _SummaryMetric(
                            label: 'المتوسط',
                            value: '${average.toStringAsFixed(0)}%',
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (_attempts.isEmpty)
                        const SizedBox(
                          height: 360,
                          child: EmptyStateView(
                            icon: Icons.assignment_outlined,
                            title: 'لا توجد محاولات اختبار',
                            message:
                                'ستظهر هنا كل اختبارات الطالب ودرجاته بعد أول محاولة.',
                          ),
                        )
                      else
                        ..._attempts.map(
                          (attempt) => Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        _managedAttemptColor(
                                          attempt,
                                        ).withAlpha(25),
                                    child: Icon(
                                      attempt.isPassed
                                          ? Icons.check_rounded
                                          : Icons.close_rounded,
                                      color: _managedAttemptColor(attempt),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          attempt.examTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${attempt.courseTitle} • المحاولة ${attempt.attemptNumber} • '
                                          '${DateFormat('yyyy/MM/dd – HH:mm').format(attempt.submittedAt)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    children: [
                                      Text(
                                        attempt.totalMarks > 0
                                            ? '${attempt.score}/${attempt.totalMarks}'
                                            : '${attempt.score}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Text(
                                        '${attempt.percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _managedAttemptColor(attempt),
                                        ),
                                      ),
                                      Text(
                                        PerformanceRating.fromPercentage(
                                          attempt.percentage,
                                        ).labelArabic,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: _managedAttemptColor(attempt),
                                        ),
                                      ),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'إدارة المحاولة',
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editAttempt(attempt);
                                      } else if (value == 'delete') {
                                        _deleteAttempt(attempt);
                                      }
                                    },
                                    itemBuilder:
                                        (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: ListTile(
                                              dense: true,
                                              leading: Icon(
                                                Icons.edit_outlined,
                                              ),
                                              title: Text(
                                                'تعديل الدرجة',
                                              ),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: ListTile(
                                              dense: true,
                                              leading: Icon(
                                                Icons.restart_alt,
                                                color: AppColors.error,
                                              ),
                                              title: Text(
                                                'حذف وإتاحة محاولة جديدة',
                                              ),
                                            ),
                                          ),
                                        ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditAttemptDialog extends StatefulWidget {
  final ManagedExamAttempt attempt;
  final StudentManagementRepository repository;

  const _EditAttemptDialog({required this.attempt, required this.repository});

  @override
  State<_EditAttemptDialog> createState() => _EditAttemptDialogState();
}

class _EditAttemptDialogState extends State<_EditAttemptDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _scoreController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scoreController = TextEditingController(text: '${widget.attempt.score}');
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateExamAttempt(
        attempt: widget.attempt,
        score: int.parse(_scoreController.text),
      );
      if (mounted) Navigator.pop(context, true);
    } on StudentManagementException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = int.tryParse(_scoreController.text) ?? 0;
    final performance =
        widget.attempt.totalMarks > 0
            ? PerformanceRating.fromScore(
              score: score,
              totalMarks: widget.attempt.totalMarks,
            )
            : PerformanceRating.fromPercentage(widget.attempt.percentage);
    final performanceColor = AppColors.forPerformance(performance.band);
    return AlertDialog(
      title: Text('تعديل: ${widget.attempt.examTitle}'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _scoreController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'الدرجة',
                  suffixText:
                      widget.attempt.totalMarks > 0
                          ? 'من ${widget.attempt.totalMarks}'
                          : null,
                ),
                validator: (value) {
                  final score = int.tryParse(value ?? '');
                  if (score == null || score < 0) return 'اكتب درجة صحيحة';
                  if (widget.attempt.totalMarks > 0 &&
                      score > widget.attempt.totalMarks) {
                    return 'الدرجة لا يمكن أن تتجاوز ${widget.attempt.totalMarks}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  performance.isSuccessful
                      ? Icons.check_circle_outline
                      : Icons.school_outlined,
                  color: performanceColor,
                ),
                title: Text(
                  performance.labelArabic,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: performanceColor,
                  ),
                ),
                subtitle: Text(
                  '${performance.percentage.toStringAsFixed(1)}% • يتم تحديد الحالة تلقائياً',
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ'),
        ),
      ],
    );
  }
}
