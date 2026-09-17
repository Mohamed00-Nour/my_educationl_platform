import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../../../core/utils/start_code_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../notifications/data/services/notification_queue_service.dart';
import '../../../notifications/presentation/widgets/push_notification_fields.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/quiz_entity.dart';
import '../../domain/repositories/quiz_repository.dart';

class QuizConfigScreen extends StatefulWidget {
  final List<QuestionEntity> initialQuestions;
  final String courseId;
  final String? unitId;
  final String? lessonId;
  final QuizEntity? existingQuiz;

  const QuizConfigScreen({
    super.key,
    this.initialQuestions = const [],
    required this.courseId,
    this.unitId,
    this.lessonId,
    this.existingQuiz,
  });

  @override
  State<QuizConfigScreen> createState() => _QuizConfigScreenState();
}

class _QuizConfigScreenState extends State<QuizConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _attemptsController = TextEditingController(text: '1');
  final _startCodeController = TextEditingController();

  late List<QuestionEntity> _questions;
  late String _selectedCourseId;
  List<Map<String, String>> _courses = [];

  QuizType _selectedType = QuizType.quiz;
  bool _requireStartCode = false;
  bool _shuffleQuestions = true;
  bool _shuffleOptions = true;
  bool _showResultImmediately = true;
  bool _showCorrectAnswers = true;
  String _showExplanations = AppConstants.explanationAfterSubmission;
  bool _isPublished = true;
  bool _isSaving = false;
  late final PushNotificationDraft _notificationDraft;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courseId;
    _notificationDraft = PushNotificationDraft(
      defaultTitle: 'اختبار جديد',
      defaultBody: 'تم نشر اختبار جديد في الكورس.',
    );

    _questions = List<QuestionEntity>.from(
      widget.initialQuestions.isNotEmpty
          ? widget.initialQuestions
          : (widget.existingQuiz?.questions ?? []),
    );

    if (widget.existingQuiz != null) {
      final q = widget.existingQuiz!;
      _titleController.text = q.title;
      _descriptionController.text = q.description;
      _durationController.text = q.durationMinutes.toString();
      _attemptsController.text = q.maxAttempts.toString();
      _selectedType = q.type;
      _requireStartCode = q.requireStartCode;
      _startCodeController.text = q.startCode ?? '';
      _shuffleQuestions = q.shuffleQuestions;
      _shuffleOptions = q.shuffleOptions;
      _showResultImmediately = q.showResultImmediately;
      _showCorrectAnswers = q.showCorrectAnswers;
      _showExplanations = q.showExplanations;
      _isPublished = q.isPublished;
      if (q.courseId.isNotEmpty) {
        _selectedCourseId = q.courseId;
      }
    } else if (_questions.length >= 20) {
      _selectedType = QuizType.fullExam;
    }

    if (_selectedCourseId.isEmpty) {
      _loadCourses();
    }
  }

  Future<void> _loadCourses() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.courses)
          .get();
      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'title': (data['title'] as String?)?.trim().isNotEmpty == true
              ? (data['title'] as String).trim()
              : 'كورس بدون عنوان',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _courses = list;
          if (_selectedCourseId.isEmpty && _courses.isNotEmpty) {
            _selectedCourseId = _courses.first['id']!;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _attemptsController.dispose();
    _startCodeController.dispose();
    _notificationDraft.dispose();
    super.dispose();
  }

  void _generateRandomCode() {
    final randomCode = StartCodeUtils.generateRandom6DigitCode();
    setState(() {
      _startCodeController.text = randomCode;
    });
  }

  void _deleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.error),
            SizedBox(width: 8),
            Text('حذف السؤال'),
          ],
        ),
        content: Text(
          'هل تريد بالتأكيد حذف السؤال رقم #${index + 1}؟',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              setState(() {
                _questions.removeAt(index);
              });
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  void _moveQuestion(int from, int to) {
    if (to < 0 || to >= _questions.length) return;
    setState(() {
      final item = _questions.removeAt(from);
      _questions.insert(to, item);
    });
  }

  void _openQuestionEditor({QuestionEntity? question, int? index}) {
    final isEditing = question != null;
    final qTextController =
        TextEditingController(text: question?.questionText ?? '');
    final topicController = TextEditingController(text: question?.topic ?? '');
    final explanationController =
        TextEditingController(text: question?.explanation ?? '');
    final marksController =
        TextEditingController(text: (question?.marks ?? 1).toString());

    String selectedType = question?.type ?? 'mcq';
    String selectedDifficulty = question?.difficulty ?? 'medium';
    int selectedCorrectIndex = question?.correctAnswerIndex ?? 0;

    List<TextEditingController> optionControllers = [];
    if (isEditing && question.options.isNotEmpty) {
      optionControllers = question.options
          .map((opt) => TextEditingController(text: opt))
          .toList();
    } else {
      if (selectedType == 'mcq') {
        optionControllers = [
          TextEditingController(text: ''),
          TextEditingController(text: ''),
          TextEditingController(text: ''),
          TextEditingController(text: ''),
        ];
      } else {
        optionControllers = [
          TextEditingController(text: 'صح'),
          TextEditingController(text: 'خطأ'),
        ];
      }
    }

    showAdaptiveModal(
      context: context,
      maxWidth: 680,
      backgroundColor: AppColors.background,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.88,
              child: Column(
                children: [
                  // Drag handle (mobile only)
                  if (ctx.isMobile)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          isEditing
                              ? Icons.edit_note_rounded
                              : Icons.add_circle_outline_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEditing
                              ? 'تعديل السؤال #${index! + 1}'
                              : 'إضافة سؤال جديد يدوياً',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type Switcher
                          const Text(
                            'نوع السؤال:',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      selectedType = 'mcq';
                                      if (optionControllers.length < 2) {
                                        optionControllers = [
                                          TextEditingController(text: ''),
                                          TextEditingController(text: ''),
                                          TextEditingController(text: ''),
                                          TextEditingController(text: ''),
                                        ];
                                      }
                                      if (selectedCorrectIndex >=
                                          optionControllers.length) {
                                        selectedCorrectIndex = 0;
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedType == 'mcq'
                                          ? AppColors.primary.withAlpha(25)
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selectedType == 'mcq'
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.list_alt_rounded,
                                          size: 18,
                                          color: selectedType == 'mcq'
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'اختيار من متعدد',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: selectedType == 'mcq'
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      selectedType = 'trueFalse';
                                      optionControllers = [
                                        TextEditingController(text: 'صح'),
                                        TextEditingController(text: 'خطأ'),
                                      ];
                                      if (selectedCorrectIndex > 1) {
                                        selectedCorrectIndex = 0;
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selectedType == 'trueFalse'
                                          ? AppColors.accent.withAlpha(25)
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selectedType == 'trueFalse'
                                            ? AppColors.accent
                                            : AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                          color: selectedType == 'trueFalse'
                                              ? AppColors.accent
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'صح أم خطأ',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: selectedType == 'trueFalse'
                                                ? AppColors.accent
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Question Text
                          AppTextField(
                            controller: qTextController,
                            label: 'نص السؤال *',
                            hintText: 'اكتب نص السؤال بوضوح هنا...',
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),

                          // Difficulty & Marks
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedDifficulty,
                                  decoration: const InputDecoration(
                                      labelText: 'مستوى الصعوبة'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'easy', child: Text('سهل')),
                                    DropdownMenuItem(
                                        value: 'medium', child: Text('متوسط')),
                                    DropdownMenuItem(
                                        value: 'hard', child: Text('صعب')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(
                                          () => selectedDifficulty = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppTextField(
                                  controller: marksController,
                                  label: 'الدرجة المستحقة',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          AppTextField(
                            controller: topicController,
                            label: 'الموضوع أو الدرس (اختياري)',
                            hintText: 'مثال: المتغيرات والأنواع الأساسية',
                          ),
                          const SizedBox(height: 20),

                          // Options / Choices Header
                          Row(
                            children: [
                              const Text(
                                'خيارات الإجابة * (اضغط لتحديد الإجابة الصحيحة):',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              if (selectedType == 'mcq' &&
                                 optionControllers.length < 6)
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('إضافة خيار',
                                      style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    setModalState(() {
                                      optionControllers
                                          .add(TextEditingController());
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (selectedType == 'trueFalse') ...[
                            ...List.generate(2, (i) {
                              final isSelected = selectedCorrectIndex == i;
                              final optionLabel = i == 0 ? 'صح' : 'خطأ';
                              final icon = i == 0
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined;
                              final activeColor =
                                  i == 0 ? AppColors.success : AppColors.error;

                              return InkWell(
                                onTap: () => setModalState(
                                    () => selectedCorrectIndex = i),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? activeColor.withAlpha(25)
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? activeColor
                                          : AppColors.border,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? activeColor
                                            : AppColors.textSecondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(icon, color: activeColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        optionLabel,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? activeColor
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: activeColor.withAlpha(30),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'الإجابة الصحيحة',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: activeColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ] else ...[
                            ...List.generate(optionControllers.length, (i) {
                              final isSelected = selectedCorrectIndex == i;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withAlpha(18)
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                      onPressed: () => setModalState(
                                          () => selectedCorrectIndex = i),
                                      tooltip: 'تحديد كإجابة صحيحة',
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: optionControllers[i],
                                        decoration: InputDecoration(
                                          hintText: 'نص الخيار ${i + 1}',
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withAlpha(30),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'صحيحة',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    if (optionControllers.length > 2)
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18, color: AppColors.error),
                                        onPressed: () {
                                          setModalState(() {
                                            optionControllers.removeAt(i);
                                            if (selectedCorrectIndex >=
                                                optionControllers.length) {
                                              selectedCorrectIndex = 0;
                                            }
                                          });
                                        },
                                        tooltip: 'حذف الخيار',
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 16),

                          // Explanation
                          AppTextField(
                            controller: explanationController,
                            label: 'التفسير أو الحل النموذجي (اختياري)',
                            hintText:
                                'اشرح للطلاب لماذا هذه الإجابة هي الصحيحة...',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 24),

                          // Save Button
                          AppButton(
                            label: isEditing ? 'تحديث السؤال' : 'إضافة السؤال',
                            icon: isEditing ? Icons.check : Icons.add,
                            backgroundColor: AppColors.primary,
                            textColor: const Color(0xFF131F24),
                            onPressed: () {
                              final text = qTextController.text.trim();
                              if (text.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('يرجى كتابة نص السؤال'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              final options = optionControllers
                                  .map((c) => c.text.trim())
                                  .toList();
                              if (options.any((opt) => opt.isEmpty)) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('يرجى ملء جميع خيارات الإجابة'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              final marks =
                                  int.tryParse(marksController.text.trim()) ??
                                      1;

                              final newQuestion = QuestionEntity(
                                id: question?.id ??
                                    'q_${DateTime.now().millisecondsSinceEpoch}_${_questions.length}',
                                type: selectedType,
                                questionText: text,
                                options: options,
                                correctAnswerIndex: selectedCorrectIndex,
                                explanation: explanationController.text.trim(),
                                marks: marks > 0 ? marks : 1,
                                difficulty: selectedDifficulty,
                                topic: topicController.text.trim().isNotEmpty
                                    ? topicController.text.trim()
                                    : null,
                                courseId: _selectedCourseId.isNotEmpty
                                    ? _selectedCourseId
                                    : null,
                              );

                              setState(() {
                                if (isEditing && index != null) {
                                  _questions[index] = newQuestion;
                                } else {
                                  _questions.add(newQuestion);
                                }
                                if (_questions.length >= 20) {
                                  _selectedType = QuizType.fullExam;
                                }
                              });

                              Navigator.pop(ctx);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _publishQuiz() async {
    if (!_formKey.currentState!.validate()) return;

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إضافة سؤال واحد على الأقل للاختبار قبل النشر'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedCourseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد الكورس المرتبط بهذا الاختبار'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (widget.existingQuiz == null) {
      final notificationError = _notificationDraft.validate();
      if (notificationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notificationError),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    if (_requireStartCode) {
      final code = _startCodeController.text.trim();
      if (code.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يرجى إدخال رمز بدء الاختبار المكون من 6 أرقام أو توليد رمز عشوائي',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (code.length != 6 || int.tryParse(code) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب أن يتكون رمز البدء من 6 أرقام رقمية'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final duration = int.tryParse(_durationController.text.trim()) ?? 30;
      final attempts = int.tryParse(_attemptsController.text.trim()) ?? 1;

      final totalMarks = _questions.fold<int>(0, (acc, q) => acc + q.marks);

      String? startCode;
      String? startCodeHash;
      String? startCodeSalt;

      if (_requireStartCode) {
        startCode = _startCodeController.text.trim();
        startCodeSalt =
            widget.existingQuiz?.startCodeSalt ?? StartCodeUtils.generateSalt();
        startCodeHash = StartCodeUtils.hashStartCode(startCode, startCodeSalt);
      }

      final quiz = QuizEntity(
        id: widget.existingQuiz?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        courseId: _selectedCourseId,
        unitId: widget.unitId,
        lessonId: widget.lessonId,
        durationMinutes: duration,
        totalMarks: totalMarks > 0 ? totalMarks : _questions.length,
        passingScore: PerformanceRating.passThreshold.round(),
        maxAttempts: attempts,
        shuffleQuestions: _shuffleQuestions,
        shuffleOptions: _shuffleOptions,
        showResultImmediately: _showResultImmediately,
        showCorrectAnswers: _showCorrectAnswers,
        showExplanations: _showExplanations,
        isPublished: _isPublished,
        questions: _questions,
        createdAt: widget.existingQuiz?.createdAt ?? DateTime.now(),
        requireStartCode: _requireStartCode,
        startCode: startCode,
        startCodeHash: startCodeHash,
        startCodeSalt: startCodeSalt,
      );

      final repo = getIt<QuizRepository>();
      if (widget.existingQuiz != null && widget.existingQuiz!.id.isNotEmpty) {
        await repo.updateQuiz(quiz);
      } else {
        final createdQuiz = await repo.createQuiz(quiz);
        final notification = _notificationDraft.buildRequest(
          courseId: _selectedCourseId,
          contentType: 'quiz',
          contentId: createdQuiz.id,
          lessonId: widget.lessonId,
        );
        if (notification != null) {
          await getIt<NotificationQueueService>().enqueueCourseNotification(
            notification,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingQuiz != null
                  ? 'تم تحديث الاختبار بنجاح!'
                  : 'تم حفظ ونشر الاختبار بنجاح!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
        if (widget.existingQuiz == null) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ الاختبار: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExam = _selectedType == QuizType.fullExam;
    final assessmentTitle = isExam ? 'الامتحان' : 'الاختبار';
    final totalMarks = _questions.fold<int>(0, (acc, q) => acc + q.marks);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingQuiz != null
              ? 'تعديل $assessmentTitle'
              : 'إعداد وتخصيص $assessmentTitle',
        ),
      ),
      body: ResponsiveContent(
        maxWidth: 920,
        child: SingleChildScrollView(
          padding: context.screenPadding,
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Course selector if needed
              if (_courses.length > 1 && widget.existingQuiz == null) ...[
                DropdownButtonFormField<String>(
                  value:
                      _selectedCourseId.isNotEmpty ? _selectedCourseId : null,
                  decoration:
                      const InputDecoration(labelText: 'الكورس التابع له *'),
                  items: _courses
                      .map((c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(c['title']!),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCourseId = val);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Title & Description
              AppTextField(
                controller: _titleController,
                label: 'عنوان $assessmentTitle *',
                hintText: isExam
                    ? 'مثال: امتحان شامل على الفصل الأول'
                    : 'مثال: اختبار قصير على درس المتغيرات',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'يرجى إدخال عنوان $assessmentTitle'
                    : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _descriptionController,
                label: 'الوصف أو التعليمات للطلاب',
                hintText:
                    'مثال: يشمل الاختبار أساسيات بايثون والمتغيرات والجمل الشرطية',
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // ==========================================
              // QUESTIONS & ANSWERS SECTION
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.quiz_rounded,
                              color: AppColors.primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'الأسئلة والإجابات (${_questions.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'إجمالي الدرجات: $totalMarks ${totalMarks == 1 ? "درجة" : "درجات"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  AppButton(
                    label: 'إضافة سؤال',
                    icon: Icons.add_rounded,
                    backgroundColor: AppColors.primary,
                    textColor: const Color(0xFF131F24),
                    width: 130,
                    height: 40,
                    borderRadius: 12,
                    bevelHeight: 3.5,
                    fontSize: 13,
                    onPressed: () => _openQuestionEditor(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Questions List or Empty Card
              if (_questions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withAlpha(50),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.post_add_rounded,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لم تقم بإضافة أي أسئلة بعد',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'أضف الأسئلة والخيارات وحدد الإجابة الصحيحة لكل سؤال يدوياً',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'إضافة أول سؤال الآن',
                        icon: Icons.add_rounded,
                        backgroundColor: AppColors.primary,
                        textColor: const Color(0xFF131F24),
                        width: 180,
                        height: 44,
                        borderRadius: 14,
                        bevelHeight: 4.0,
                        onPressed: () => _openQuestionEditor(),
                      ),
                    ],
                  ),
                )
              else ...[
                // List of question cards
                ...List.generate(_questions.length, (idx) {
                  final q = _questions[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#${idx + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: q.isMcq
                                    ? AppColors.secondary.withAlpha(25)
                                    : AppColors.accent.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                q.isMcq ? 'اختيار من متعدد' : 'صح أم خطأ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: q.isMcq
                                      ? AppColors.secondary
                                      : AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.bonus.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${q.marks} ${q.marks == 1 ? "درجة" : "درجات"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.bonus,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Up / Down
                            if (_questions.length > 1) ...[
                              if (idx > 0)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.arrow_upward,
                                      size: 16),
                                  onPressed: () =>
                                      _moveQuestion(idx, idx - 1),
                                  tooltip: 'تحريك لأعلى',
                                ),
                              if (idx < _questions.length - 1)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.arrow_downward,
                                      size: 16),
                                  onPressed: () =>
                                      _moveQuestion(idx, idx + 1),
                                  tooltip: 'تحريك لأسفل',
                                ),
                            ],
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.secondary),
                              onPressed: () => _openQuestionEditor(
                                question: q,
                                index: idx,
                              ),
                              tooltip: 'تعديل السؤال',
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.error),
                              onPressed: () => _deleteQuestion(idx),
                              tooltip: 'حذف السؤال',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Question Text
                        Text(
                          q.questionText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Options preview
                        ...List.generate(q.options.length, (optIdx) {
                          final isCorrect = optIdx == q.correctAnswerIndex;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? AppColors.primary.withAlpha(20)
                                  : AppColors.surfaceVariant.withAlpha(40),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCorrect
                                    ? AppColors.primary
                                    : AppColors.border.withAlpha(60),
                                width: isCorrect ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCorrect
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: isCorrect
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.options[optIdx],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCorrect
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isCorrect
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (isCorrect)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'صحيحة',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),

                        // Explanation if present
                        if (q.explanation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.secondary.withAlpha(40)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_outline,
                                    size: 16, color: AppColors.secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'التفسير: ${q.explanation}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Center(
                  child: AppButton(
                    label: 'إضافة سؤال آخر',
                    icon: Icons.add,
                    isOutlined: true,
                    width: 170,
                    height: 42,
                    borderRadius: 12,
                    bevelHeight: 3.5,
                    fontSize: 13,
                    onPressed: () => _openQuestionEditor(),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // ==========================================
              // ASSESSMENT SETTINGS SECTION
              // ==========================================
              const Row(
                children: [
                  Icon(Icons.tune_rounded,
                      color: AppColors.secondary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'إعدادات الاختبار والوقت',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Assessment Type & Duration
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<QuizType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'نوع التقييم',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: QuizType.quiz,
                          child: Text('اختبار درس / قصير'),
                        ),
                        DropdownMenuItem(
                          value: QuizType.fullExam,
                          child: Text('امتحان شامل'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _durationController,
                      label: 'المدة (بالدقائق)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Unified performance policy & max attempts
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نظام التقييم الموحد',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'أقل من 50% يحتاج تدريب • 50–89.99% جيد • 90–99.99% جيد جداً • 100% ممتاز',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _attemptsController,
                      label: 'المحاولات المسموح بها',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Start Code Configuration Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _requireStartCode
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isExam
                              ? 'طلب رمز بدء الامتحان (Start Exam Code)'
                              : 'طلب رمز بدء الاختبار (Start Quiz Code)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'لا يمكن للطالب بدء الإجابة في الفصل إلا بعد إدخال الرمز السري',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        value: _requireStartCode,
                        onChanged: (val) {
                          setState(() {
                            _requireStartCode = val;
                            if (val && _startCodeController.text.isEmpty) {
                              _generateRandomCode();
                            }
                          });
                        },
                      ),
                      if (_requireStartCode) ...[
                        const Divider(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _startCodeController,
                                label: isExam
                                    ? 'رمز بدء الامتحان (6 أرقام)'
                                    : 'رمز بدء الاختبار (6 أرقام)',
                                hintText: 'مثال: 789123',
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.shuffle, size: 18),
                                label: const Text('توليد رمز عشوائي'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(120, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _generateRandomCode,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.security,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'أمان مشفر: يتم تخزين الرمز كـ Salted Hash على جهاز الطالب ويعمل التحقق بالكامل بدون إنترنت.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Explanation Visibility
              DropdownButtonFormField<String>(
                value: _showExplanations,
                decoration: const InputDecoration(
                  labelText: 'متى تظهر التفسيرات والإجابات النموذجية',
                ),
                items: const [
                  DropdownMenuItem(
                    value: AppConstants.explanationAfterSubmission,
                    child: Text('مباشرة فور تسليم الاختبار'),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.explanationAfterExamEnds,
                    child: Text('فقط بعد انتهاء فترة صلاحية الاختبار'),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.explanationNever,
                    child: Text('عدم إظهار التفسيرات إطلاقاً'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _showExplanations = val);
                },
              ),
              const SizedBox(height: 20),

              // Switch Settings Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'ترتيب عشوائي للأسئلة لكل طالب',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _shuffleQuestions,
                        onChanged: (val) =>
                            setState(() => _shuffleQuestions = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text(
                          'ترتيب عشوائي لخيارات الإجابة',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _shuffleOptions,
                        onChanged: (val) =>
                            setState(() => _shuffleOptions = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text(
                          'إظهار النتيجة والدرجة للطالب فوراً',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _showResultImmediately,
                        onChanged: (val) =>
                            setState(() => _showResultImmediately = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text(
                          'إظهار الإجابات الصحيحة عند المراجعة',
                          style: TextStyle(fontSize: 14),
                        ),
                        value: _showCorrectAnswers,
                        onChanged: (val) =>
                            setState(() => _showCorrectAnswers = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: Text(
                          'نشر $assessmentTitle فوراً (يظهر للطلاب الآن)',
                          style: const TextStyle(fontSize: 14),
                        ),
                        value: _isPublished,
                        onChanged: (val) =>
                            setState(() => _isPublished = val),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.existingQuiz == null)
                PushNotificationFields(draft: _notificationDraft),
              const SizedBox(height: 28),

              AppButton(
                label: widget.existingQuiz != null
                    ? 'حفظ التعديلات الآن'
                    : 'حفظ ونشر $assessmentTitle الآن',
                isLoading: _isSaving,
                icon: widget.existingQuiz != null
                    ? Icons.save_outlined
                    : Icons.rocket_launch_outlined,
                onPressed: _publishQuiz,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}
}
