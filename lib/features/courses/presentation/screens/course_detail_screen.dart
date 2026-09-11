import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/datasources/ministry_course_seeder.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../domain/entities/unit_entity.dart';
import '../../../quizzes/presentation/screens/admin_quiz_management_screen.dart';
import '../bloc/course_bloc.dart';
import 'lesson_detail_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseEntity course;
  final UserEntity user;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.user,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure the course units and lessons are loaded and real-time streamed from Firebase
    context.read<CourseBloc>().add(SelectCourseRequested(widget.course.id));
    context.read<CourseBloc>().add(StreamCourseDetailsRequested(widget.course.id));
  }

  // ================= MINISTRY SEED IMPORT PREVIEW & CONFIRMATION =================
  Future<void> _showImportMinistrySeedDialog(int existingUnitsCount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    MinistrySeedPreview? preview;
    try {
      final seeder = MinistryCourseSeeder();
      preview = await seeder.loadPreview();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر قراءة بيانات المنهج: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // close loader

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'استيراد منهج الوزارة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview!.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${preview.grade} • العام الدراسي ${preview.academicYear}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatChip(
                          icon: Icons.layers_outlined,
                          label: '${preview.unitsCount} وحدة',
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          icon: Icons.menu_book_outlined,
                          label: '${preview.lessonsCount} درساً',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'عيّنة من الوحدات التي سيتم إنشاؤها:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              ...preview.sampleUnitTitles.take(4).map(
                    (title) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (preview.sampleUnitTitles.length > 4)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '... بالإضافة إلى ${preview.sampleUnitTitles.length - 4} وحدات أخرى بجميع دروسها.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              if (existingUnitsCount > 0)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withAlpha(90)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تنبيه: يحتوي الكورس على $existingUnitsCount وحدة حالياً. الاستيراد سيضيف وحدات المنهج ككيانات جديدة قابلة للتعديل والتحرير.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withAlpha(90)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: AppColors.info, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'بعد الاستيراد، ستصبح جميع الوحدات والدروس كيانات مستقلة يمكنك تعديلها وإعادة ترتيبها ونشرها بالكامل.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_download_rounded, size: 18),
            label: const Text('تأكيد الاستيراد'),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CourseBloc>().add(
                    ImportMinistrySeedRequested(courseId: widget.course.id),
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ================= UNIT CRUD DIALOGS =================
  void _showAddUnitDialog(BuildContext context, int currentUnitsCount) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final pageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة وحدة دراسية جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الوحدة *',
                  hintText: 'مثال: الوحدة الأولى: مقدمة في البرمجة',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'الوصف أو المخرجات التعليمية',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pageController,
                decoration: const InputDecoration(
                  labelText: 'رقم صفحة البداية بالكتاب المدرسي (اختياري)',
                  hintText: 'مثال: 15',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final startPage = int.tryParse(pageController.text.trim());
                final newUnit = UnitEntity(
                  id: '',
                  courseId: widget.course.id,
                  title: title,
                  description: descController.text.trim(),
                  order: currentUnitsCount + 1,
                  bookStartPage: startPage,
                  isPublished: true,
                );
                context.read<CourseBloc>().add(CreateUnitRequested(newUnit));
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة الوحدة'),
          ),
        ],
      ),
    );
  }

  void _showEditUnitDialog(BuildContext context, UnitEntity unit) {
    final titleController = TextEditingController(text: unit.title);
    final descController = TextEditingController(text: unit.description);
    final pageController = TextEditingController(
      text: unit.bookStartPage != null ? unit.bookStartPage.toString() : '',
    );
    bool isPublished = unit.isPublished;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تعديل الوحدة الدراسية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'عنوان الوحدة *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pageController,
                  decoration: const InputDecoration(
                    labelText: 'رقم صفحة البداية بالكتاب المدرسي',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'نشر الوحدة للطلاب',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isPublished ? 'الوحدة معروضة للطلاب' : 'الوحدة مخفية (مسودة)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: isPublished,
                  onChanged: (val) {
                    setDialogState(() => isPublished = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  final startPage = int.tryParse(pageController.text.trim());
                  final updatedUnit = unit.copyWith(
                    title: title,
                    description: descController.text.trim(),
                    bookStartPage: startPage,
                    isPublished: isPublished,
                  );
                  context.read<CourseBloc>().add(UpdateUnitRequested(updatedUnit));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showArchiveUnitDialog(BuildContext context, UnitEntity unit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: AppColors.warning),
            SizedBox(width: 8),
            Text('أرشفة الوحدة الدراسية'),
          ],
        ),
        content: Text(
          'هل تريد أرشفة وحدة "${unit.title}"؟\nسيتم إخفاء الوحدة وجميع دروسها من واجهة الطلاب، مع الاحتفاظ بجميع بيانات تقدم الطلاب والامتحانات السابقة بأمان.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<CourseBloc>().add(
                    DeleteUnitRequested(
                      unitId: unit.id,
                      courseId: widget.course.id,
                      softDelete: true,
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد الأرشفة'),
          ),
        ],
      ),
    );
  }

  // ================= LESSON CRUD DIALOGS =================
  void _showAddLessonDialog(BuildContext context, UnitEntity unit, int currentLessonsCount) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final pageController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة درس إلى ${unit.title}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الدرس *',
                  hintText: 'مثال: الدرس الأول: مدخل للبرمجة',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'الوصف أو الأهداف'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pageController,
                decoration: const InputDecoration(
                  labelText: 'رقم صفحة الدرس بالكتاب المدرسي (اختياري)',
                  hintText: 'مثال: 22',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'توجيهات أو ملاحظات للطلاب (اختياري)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                final startPage = int.tryParse(pageController.text.trim());
                final newLesson = LessonEntity(
                  id: '',
                  courseId: widget.course.id,
                  unitId: unit.id,
                  title: title,
                  description: descController.text.trim(),
                  order: currentLessonsCount + 1,
                  bookStartPage: startPage,
                  notes: notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : null,
                  isPublished: true,
                );
                context.read<CourseBloc>().add(CreateLessonRequested(newLesson));
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة الدرس'),
          ),
        ],
      ),
    );
  }

  void _showEditLessonDialog(BuildContext context, LessonEntity lesson) {
    final titleController = TextEditingController(text: lesson.title);
    final descController = TextEditingController(text: lesson.description);
    final pageController = TextEditingController(
      text: lesson.bookStartPage != null ? lesson.bookStartPage.toString() : '',
    );
    final notesController = TextEditingController(text: lesson.notes ?? '');
    bool isPublished = lesson.isPublished;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تعديل الدرس'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'عنوان الدرس *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'الوصف أو الأهداف'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pageController,
                  decoration: const InputDecoration(
                    labelText: 'رقم صفحة الدرس بالكتاب المدرسي',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'توجيهات أو ملاحظات المعلم للطلاب',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'نشر الدرس للطلاب',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isPublished ? 'الدرس معروض للطلاب' : 'الدرس مخفي (مسودة)',
                    style: const TextStyle(fontSize: 11),
                  ),
                  value: isPublished,
                  onChanged: (val) {
                    setDialogState(() => isPublished = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  final startPage = int.tryParse(pageController.text.trim());
                  final updatedLesson = lesson.copyWith(
                    title: title,
                    description: descController.text.trim(),
                    bookStartPage: startPage,
                    notes: notesController.text.trim().isNotEmpty
                        ? notesController.text.trim()
                        : null,
                    isPublished: isPublished,
                  );
                  context.read<CourseBloc>().add(UpdateLessonRequested(updatedLesson));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showArchiveLessonDialog(BuildContext context, LessonEntity lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: AppColors.warning),
            SizedBox(width: 8),
            Text('أرشفة الدرس'),
          ],
        ),
        content: Text(
          'هل تريد أرشفة درس "${lesson.title}"؟\nسيتم إخفاء الدرس من واجهة الطلاب مع الحفاظ على سجلات حل الاختبارات السابقة.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<CourseBloc>().add(
                    DeleteLessonRequested(
                      lessonId: lesson.id,
                      unitId: lesson.unitId,
                      courseId: widget.course.id,
                      softDelete: true,
                    ),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('تأكيد الأرشفة'),
          ),
        ],
      ),
    );
  }

  // ================= COURSE EDIT & DELETE =================
  void _showEditCourseDialog(BuildContext context) {
    final titleController = TextEditingController(text: widget.course.title);
    final descController = TextEditingController(text: widget.course.description);
    final yearController = TextEditingController(text: widget.course.academicYear);
    StudentGrade selectedGrade =
        widget.course.targetGrade ?? StudentGrade.firstSecondary;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تعديل بيانات الكورس'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'اسم الكورس'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(labelText: 'العام الدراسي'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'الصف الدراسي المستهدف:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text(StudentGrade.firstSecondary.toArabicDisplay()),
                        selected: selectedGrade == StudentGrade.firstSecondary,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() => selectedGrade = StudentGrade.firstSecondary);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(StudentGrade.secondSecondary.toArabicDisplay()),
                        selected: selectedGrade == StudentGrade.secondSecondary,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() => selectedGrade = StudentGrade.secondSecondary);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  final updated = widget.course.copyWith(
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                    academicYear: yearController.text.trim(),
                    targetGrade: selectedGrade,
                  );
                  context.read<CourseBloc>().add(UpdateCourseRequested(updated));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCourseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('حذف الكورس'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف كورس "${widget.course.title}"؟\nسيتم حذف الكورس وجميع الوحدات والدروس المرتبطة به نهائياً.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              context.read<CourseBloc>().add(DeleteCourseRequested(widget.course.id));
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  // ================= REORDER HANDLERS =================
  void _moveUnit(List<UnitEntity> units, int currentIndex, int targetIndex) {
    if (targetIndex < 0 || targetIndex >= units.length) return;
    final reordered = List<UnitEntity>.from(units);
    final item = reordered.removeAt(currentIndex);
    reordered.insert(targetIndex, item);
    context.read<CourseBloc>().add(
          ReorderUnitsRequested(
            courseId: widget.course.id,
            units: reordered,
          ),
        );
  }

  void _moveLesson(String unitId, List<LessonEntity> lessons, int currentIndex, int targetIndex) {
    if (targetIndex < 0 || targetIndex >= lessons.length) return;
    final reordered = List<LessonEntity>.from(lessons);
    final item = reordered.removeAt(currentIndex);
    reordered.insert(targetIndex, item);
    context.read<CourseBloc>().add(
          ReorderLessonsRequested(
            unitId: unitId,
            lessons: reordered,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
        actions: [
          if (widget.user.isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.quiz_outlined),
              tooltip: 'إدارة اختبارات الكورس',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminQuizManagementScreen(
                      user: widget.user,
                      courseId: widget.course.id,
                      courseTitle: widget.course.title,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'إضافة وحدة جديدة',
              onPressed: () {
                final state = context.read<CourseBloc>().state;
                final count = state is CourseLoaded ? state.units.length : 0;
                _showAddUnitDialog(context, count);
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'خيارات الكورس',
              onSelected: (val) {
                final state = context.read<CourseBloc>().state;
                final count = state is CourseLoaded ? state.units.length : 0;
                if (val == 'manage_quizzes') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminQuizManagementScreen(
                        user: widget.user,
                        courseId: widget.course.id,
                        courseTitle: widget.course.title,
                      ),
                    ),
                  );
                } else if (val == 'import') {
                  _showImportMinistrySeedDialog(count);
                } else if (val == 'add_unit') {
                  _showAddUnitDialog(context, count);
                } else if (val == 'edit') {
                  _showEditCourseDialog(context);
                } else if (val == 'delete') {
                  _showDeleteCourseDialog(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'manage_quizzes',
                  child: Row(
                    children: [
                      Icon(Icons.quiz_outlined, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'إدارة اختبارات الكورس',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.auto_stories_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'استيراد منهج الوزارة',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_unit',
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryLight),
                      SizedBox(width: 8),
                      Text(
                        'إضافة وحدة دراسية',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                      SizedBox(width: 8),
                      Text(
                        'تعديل بيانات الكورس',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text(
                        'حذف الكورس',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: BlocConsumer<CourseBloc, CourseState>(
        listener: (context, state) {
          if (state is CourseLoaded && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is CourseError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CourseLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CourseLoaded) {
            final units = state.units;
            if (units.isEmpty) {
              if (widget.user.isAdmin) {
                return _buildAdminEmptyState(context);
              }
              return const EmptyStateView(
                icon: Icons.layers_clear_outlined,
                title: 'لا توجد وحدات دراسية بعد',
                message: 'سيتم عرض الوحدات والدروس هنا بمجرد إضافتها من قِبل المعلم.',
              );
            }

            return ResponsiveContent(
              maxWidth: 960,
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<CourseBloc>().add(SelectCourseRequested(widget.course.id));
                  context.read<CourseBloc>().add(StreamCourseDetailsRequested(widget.course.id));
                },
                child: ListView.builder(
                  padding: context.screenPadding,
                  itemCount: units.length,
                  itemBuilder: (context, index) {
                    final unit = units[index];
                    final lessons = state.lessonsByUnit[unit.id] ?? [];

                    return _UnitAccordion(
                      unit: unit,
                      lessons: lessons,
                      isAdmin: widget.user.isAdmin,
                      canMoveUp: index > 0,
                      canMoveDown: index < units.length - 1,
                      onMoveUp: () => _moveUnit(units, index, index - 1),
                      onMoveDown: () => _moveUnit(units, index, index + 1),
                      onEditUnit: () => _showEditUnitDialog(context, unit),
                      onArchiveUnit: () => _showArchiveUnitDialog(context, unit),
                      onTogglePublishUnit: () {
                        context.read<CourseBloc>().add(
                              UpdateUnitRequested(
                                unit.copyWith(isPublished: !unit.isPublished),
                              ),
                            );
                      },
                      onAddLesson: () => _showAddLessonDialog(context, unit, lessons.length),
                      onEditLesson: (lesson) => _showEditLessonDialog(context, lesson),
                      onArchiveLesson: (lesson) => _showArchiveLessonDialog(context, lesson),
                      onTogglePublishLesson: (lesson) {
                        context.read<CourseBloc>().add(
                              UpdateLessonRequested(
                                lesson.copyWith(isPublished: !lesson.isPublished),
                              ),
                            );
                      },
                      onMoveLessonUp: (i) => _moveLesson(unit.id, lessons, i, i - 1),
                      onMoveLessonDown: (i) => _moveLesson(unit.id, lessons, i, i + 1),
                      onTapLesson: (lesson) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LessonDetailScreen(
                              lesson: lesson,
                              user: widget.user,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            );
        }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAdminEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'لا توجد وحدات دراسية بعد',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'يمكنك استيراد هيكل منهج وزارة التربية والتعليم كاملاً (13 وحدة • 45 درساً) بنقرة واحدة ككيانات قابلة للتعديل بالكامل، أو البدء بإضافة وحدات مخصصة يدوياً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cloud_download_rounded),
                label: const Text(
                  'استيراد منهج الوزارة (13 وحدة • 45 درساً)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showImportMinistrySeedDialog(0),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('إضافة وحدة دراسية يدوياً'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showAddUnitDialog(context, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= UNIT ACCORDION WIDGET =================
class _UnitAccordion extends StatelessWidget {
  final UnitEntity unit;
  final List<LessonEntity> lessons;
  final bool isAdmin;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onEditUnit;
  final VoidCallback onArchiveUnit;
  final VoidCallback onTogglePublishUnit;
  final VoidCallback onAddLesson;
  final ValueChanged<LessonEntity> onEditLesson;
  final ValueChanged<LessonEntity> onArchiveLesson;
  final ValueChanged<LessonEntity> onTogglePublishLesson;
  final ValueChanged<int> onMoveLessonUp;
  final ValueChanged<int> onMoveLessonDown;
  final ValueChanged<LessonEntity> onTapLesson;

  const _UnitAccordion({
    required this.unit,
    required this.lessons,
    required this.isAdmin,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEditUnit,
    required this.onArchiveUnit,
    required this.onTogglePublishUnit,
    required this.onAddLesson,
    required this.onEditLesson,
    required this.onArchiveLesson,
    required this.onTogglePublishLesson,
    required this.onMoveLessonUp,
    required this.onMoveLessonDown,
    required this.onTapLesson,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unit.isPublished ? AppColors.border : AppColors.warning.withAlpha(90),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  unit.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: unit.isPublished ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
              if (!unit.isPublished) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withAlpha(60),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'مسودة',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
              if (unit.bookStartPage != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'صـ ${unit.bookStartPage}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: unit.description.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    unit.description,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                )
              : null,
          trailing: isAdmin
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'إدارة الوحدة',
                  onSelected: (val) {
                    if (val == 'edit') onEditUnit();
                    if (val == 'add_lesson') onAddLesson();
                    if (val == 'publish') onTogglePublishUnit();
                    if (val == 'move_up') onMoveUp();
                    if (val == 'move_down') onMoveDown();
                    if (val == 'archive') onArchiveUnit();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('تعديل الوحدة', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'add_lesson',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16, color: AppColors.primaryLight),
                          SizedBox(width: 8),
                          Text('إضافة درس', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'publish',
                      child: Row(
                        children: [
                          Icon(
                            unit.isPublished
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            unit.isPublished ? 'إلغاء النشر (مسودة)' : 'نشر للطلاب',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (canMoveUp)
                      const PopupMenuItem(
                        value: 'move_up',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward, size: 16),
                            SizedBox(width: 8),
                            Text('نقل لأعلى', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    if (canMoveDown)
                      const PopupMenuItem(
                        value: 'move_down',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, size: 16),
                            SizedBox(width: 8),
                            Text('نقل لأسفل', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 16, color: AppColors.warning),
                          SizedBox(width: 8),
                          Text(
                            'أرشفة الوحدة',
                            style: TextStyle(fontSize: 13, color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
          children: [
            const Divider(height: 1),
            if (lessons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'لا توجد دروس في هذه الوحدة.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    if (isAdmin)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة أول درس'),
                        onPressed: onAddLesson,
                      ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lessons.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                itemBuilder: (context, i) {
                  final lesson = lessons[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: lesson.isPublished
                            ? AppColors.primary.withAlpha(20)
                            : AppColors.textMuted.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: lesson.isPublished ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: lesson.isPublished
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (!lesson.isPublished) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight.withAlpha(60),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'مسودة',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        if (lesson.bookStartPage != null) ...[
                          Text(
                            'كتاب الوزارة صـ ${lesson.bookStartPage}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${lesson.materials.length} ملحقات',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (lesson.quizId != null) ...[
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                          const Icon(Icons.quiz_outlined, size: 12, color: AppColors.primaryLight),
                          const SizedBox(width: 3),
                          const Text(
                            'اختبار',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: isAdmin
                        ? PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            tooltip: 'إدارة الدرس',
                            onSelected: (val) {
                              if (val == 'edit') onEditLesson(lesson);
                              if (val == 'publish') onTogglePublishLesson(lesson);
                              if (val == 'move_up') onMoveLessonUp(i);
                              if (val == 'move_down') onMoveLessonDown(i);
                              if (val == 'archive') onArchiveLesson(lesson);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text('تعديل الدرس', style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'publish',
                                child: Row(
                                  children: [
                                    Icon(
                                      lesson.isPublished
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      lesson.isPublished ? 'إلغاء النشر' : 'نشر للطلاب',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if (i > 0)
                                const PopupMenuItem(
                                  value: 'move_up',
                                  child: Row(
                                    children: [
                                      Icon(Icons.arrow_upward, size: 16),
                                      SizedBox(width: 8),
                                      Text('نقل لأعلى', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                              if (i < lessons.length - 1)
                                const PopupMenuItem(
                                  value: 'move_down',
                                  child: Row(
                                    children: [
                                      Icon(Icons.arrow_downward, size: 16),
                                      SizedBox(width: 8),
                                      Text('نقل لأسفل', style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'archive',
                                child: Row(
                                  children: [
                                    Icon(Icons.archive_outlined, size: 16, color: AppColors.warning),
                                    SizedBox(width: 8),
                                    Text(
                                      'أرشفة الدرس',
                                      style: TextStyle(fontSize: 13, color: AppColors.warning),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                    onTap: () => onTapLesson(lesson),
                  );
                },
              ),
            if (isAdmin && lessons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إضافة درس'),
                    onPressed: onAddLesson,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
