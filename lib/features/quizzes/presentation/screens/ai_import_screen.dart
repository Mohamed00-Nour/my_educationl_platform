import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/ai_import_item.dart';
import '../blocs/ai_import_bloc.dart';
import 'quiz_config_screen.dart';

class AIImportScreen extends StatefulWidget {
  final String? courseId;
  const AIImportScreen({super.key, this.courseId});

  @override
  State<AIImportScreen> createState() => _AIImportScreenState();
}

class _AIImportScreenState extends State<AIImportScreen> {
  final _inputController = TextEditingController();

  void _pasteSampleJson() {
    _inputController.text = '''[
  {
    "type": "mcq",
    "question": "ما هو المتغير (Variable) في لغة البرمجة؟",
    "options": [
      "مكان في الذاكرة لتخزين البيانات",
      "لغة برمجة خاصة",
      "نظام تشغيل",
      "جهاز حاسوب"
    ],
    "correctAnswer": 0,
    "explanation": "المتغير هو مساحة محجوزة في الذاكرة لتخزين قيمة يمكن قراءتها وتعديلها أثناء تنفيذ البرنامج.",
    "difficulty": "easy"
  },
  {
    "type": "trueFalse",
    "question": "تُستخدم جملة التكرار (Loop) لتكرار تنفيذ جزء من الكود عدة مرات.",
    "options": ["صح", "خطأ"],
    "correctAnswer": 0,
    "explanation": "تكرارات مثل for و while تستخدم لتكرار التعليمات طالما تحقق الشرط.",
    "difficulty": "easy"
  },
  {
    "type": "mcq",
    "question": "أي المعاملات التالية يُستخدم للقسمة الصحيحة (Floor Division) في بايثون؟",
    "options": ["/", "//", "%", "**"],
    "correctAnswer": 1,
    "explanation": "المعامل // يقوم بالقسمة مع استبعاد الجزء العشري وإرجاع العدد الصحيح.",
    "difficulty": "medium"
  }
]''';
  }

  void _openEditDialog(BuildContext context, AIImportItem item) {
    final qTextController = TextEditingController(
      text: item.question.questionText,
    );
    final explanationController = TextEditingController(
      text: item.question.explanation,
    );
    final List<TextEditingController> optionControllers =
        item.question.options
            .map((opt) => TextEditingController(text: opt))
            .toList();
    int selectedCorrectIndex = item.question.correctAnswerIndex;
    String selectedDifficulty = item.question.difficulty;
    String selectedType = item.question.type;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text('تعديل السؤال #${item.index}'),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 500,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: qTextController,
                          decoration: const InputDecoration(
                            labelText: 'نص السؤال',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedType,
                                decoration: const InputDecoration(
                                  labelText: 'النوع',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'mcq',
                                    child: Text('اختيار من متعدد'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'trueFalse',
                                    child: Text('صح أو خطأ'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedType = val;
                                      if (val == 'trueFalse') {
                                        optionControllers.clear();
                                        optionControllers.add(
                                          TextEditingController(text: 'صح'),
                                        );
                                        optionControllers.add(
                                          TextEditingController(text: 'خطأ'),
                                        );
                                        selectedCorrectIndex = 0;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedDifficulty,
                                decoration: const InputDecoration(
                                  labelText: 'الصعوبة',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'easy',
                                    child: Text('سهل'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'medium',
                                    child: Text('متوسط'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'hard',
                                    child: Text('صعب'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null)
                                    setDialogState(
                                      () => selectedDifficulty = val,
                                    );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'الخيارات (حدد الإجابة الصحيحة):',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...List.generate(optionControllers.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Radio<int>(
                                  value: i,
                                  groupValue: selectedCorrectIndex,
                                  onChanged: (val) {
                                    if (val != null)
                                      setDialogState(
                                        () => selectedCorrectIndex = val,
                                      );
                                  },
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: optionControllers[i],
                                    decoration: InputDecoration(
                                      labelText: 'الخيار ${i + 1}',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                                  ),
                                ),
                                if (selectedType == 'mcq' &&
                                    optionControllers.length > 2)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () {
                                      setDialogState(() {
                                        optionControllers.removeAt(i);
                                        if (selectedCorrectIndex >=
                                            optionControllers.length) {
                                          selectedCorrectIndex = 0;
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (selectedType == 'mcq')
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('إضافة خيار'),
                            onPressed: () {
                              setDialogState(() {
                                optionControllers.add(
                                  TextEditingController(text: ''),
                                );
                              });
                            },
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: explanationController,
                          decoration: const InputDecoration(
                            labelText: 'التفسير والشرح التعليمي',
                            hintText: 'لماذا هذه الإجابة هي الصحيحة...',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final updatedQ = item.question.copyWith(
                        type: selectedType,
                        questionText: qTextController.text.trim(),
                        options:
                            optionControllers
                                .map((c) => c.text.trim())
                                .toList(),
                        correctAnswerIndex: selectedCorrectIndex,
                        explanation: explanationController.text.trim(),
                        difficulty: selectedDifficulty,
                      );

                      context.read<AIImportBloc>().add(
                        UpdateImportedQuestionEvent(item.index, updatedQ),
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('حفظ التعديلات'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استيراد الأسئلة'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('نموذج JSON'),
            onPressed: _pasteSampleJson,
          ),
        ],
      ),
      body: BlocConsumer<AIImportBloc, AIImportState>(
        listener: (context, state) {
          if (state is AIImportSavedToBankSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'تم حفظ ${state.count} أسئلة في بنك الأسئلة بنجاح!',
                ),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (state is AIImportErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return ResponsiveContent(
            maxWidth: 1050,
            padding: context.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Input Section (Collapsible if preview active)
                if (state is! AIImportPreviewState) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.psychology_outlined,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'الصق كود JSON للأسئلة',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'انسخ الأسئلة بصيغة JSON والصقها هنا. سيقوم النظام بفحص سلامة التنسيق، الإجابات الصحيحة، والتكرار تلقائياً.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _inputController,
                            maxLines: 8,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  '[\n  {\n    "question": "ما هو المتغير؟", ...\n  }\n]',
                            ),
                          ),
                          const SizedBox(height: 14),
                          AppButton(
                            label: 'التحقق من صحة الأسئلة الملتصقة',
                            icon: Icons.check_circle_outline,
                            onPressed: () {
                              final text = _inputController.text.trim();
                              if (text.isNotEmpty) {
                                context.read<AIImportBloc>().add(
                                  ParseAndValidateRawInputEvent(text),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Preview Section
                if (state is AIImportLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (state is AIImportPreviewState) ...[
                  // Summary Banner
                  Card(
                    color:
                        state.summary.hasErrors
                            ? AppColors.warningLight
                            : AppColors.successLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color:
                            state.summary.hasErrors
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            state.summary.hasErrors
                                ? Icons.warning_amber_rounded
                                : Icons.verified_outlined,
                            color:
                                state.summary.hasErrors
                                    ? AppColors.warning
                                    : AppColors.success,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تم رصد ${state.summary.totalDetected} سؤال  •  ${state.summary.validCount} صحيح  •  ${state.summary.needsReviewCount} بحاجة لمراجعة',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  state.summary.hasErrors
                                      ? 'يرجى مراجعة الأسئلة غير المكتملة أدناه قبل المتابعة.'
                                      : 'تم التحقق من صحة جميع الأسئلة وجاهزة للاستخدام والنشر.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              context.read<AIImportBloc>().add(
                                const ParseAndValidateRawInputEvent(''),
                              );
                            },
                            child: const Text('لصق من جديد'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Questions List
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.summary.items.length,
                      itemBuilder: (context, index) {
                        final item = state.summary.items[index];
                        return _ImportedQuestionCard(
                          item: item,
                          onEdit: () => _openEditDialog(context, item),
                          onDelete: () {
                            context.read<AIImportBloc>().add(
                              DeleteImportedQuestionEvent(item.index),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'حفظ في بنك الأسئلة',
                            isOutlined: true,
                            icon: Icons.archive_outlined,
                            onPressed: () {
                              context.read<AIImportBloc>().add(
                                SaveToQuestionBankEvent(
                                  courseId: widget.courseId,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            label: 'إعداد ونشر الاختبار',
                            icon: Icons.tune_rounded,
                            onPressed:
                                state.summary.validCount > 0
                                    ? () {
                                      final validQuestions =
                                          state.summary.items
                                              .where((i) => i.isValid)
                                              .map((i) => i.question)
                                              .toList();

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => QuizConfigScreen(
                                                initialQuestions:
                                                    validQuestions,
                                                courseId: widget.courseId ?? '',
                                              ),
                                        ),
                                      );
                                    }
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImportedQuestionCard extends StatelessWidget {
  final AIImportItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ImportedQuestionCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isValid ? AppColors.border : AppColors.error,
          width: item.isValid ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '#${item.index}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      StatusBadge.difficulty(item.question.difficulty),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item.question.isMcq ? 'اختيار من متعدد' : 'صح أو خطأ',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.isValid)
                        const StatusBadge(
                          label: 'صحيح',
                          backgroundColor: AppColors.successLight,
                          textColor: AppColors.success,
                          icon: Icons.check,
                        )
                      else
                        const StatusBadge(
                          label: 'يحتاج مراجعة',
                          backgroundColor: AppColors.errorLight,
                          textColor: AppColors.error,
                          icon: Icons.priority_high,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'تعديل السؤال',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: onEdit,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'حذف السؤال',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.question.questionText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Options List
            ...List.generate(item.question.options.length, (optIdx) {
              final isCorrect = optIdx == item.question.correctAnswerIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color:
                          isCorrect ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.question.options[optIdx],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isCorrect ? FontWeight.w600 : FontWeight.normal,
                          color:
                              isCorrect
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (item.question.explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'التفسير: ${item.question.explanation}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Validation Error Chips
            if (item.errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    item.errors
                        .map(
                          (err) => Chip(
                            backgroundColor: AppColors.errorLight,
                            label: Text(
                              err,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
