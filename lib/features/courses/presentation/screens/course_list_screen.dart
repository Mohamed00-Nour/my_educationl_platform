import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/course_entity.dart';
import '../bloc/course_bloc.dart';
import '../widgets/course_import_dialog.dart';
import 'course_detail_screen.dart';

class CourseListScreen extends StatefulWidget {
  final UserEntity user;

  const CourseListScreen({super.key, required this.user});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CourseBloc>().add(const FetchCoursesRequested());
  }

  void _showImportJsonDialog(BuildContext context) {
    final state = context.read<CourseBloc>().state;
    final List<String> existingTitles = [];
    if (state is CourseLoaded) {
      existingTitles.addAll(state.courses.map((c) => c.title));
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CourseImportDialog(
        user: widget.user,
        existingCourseTitles: existingTitles,
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final yearController = TextEditingController(text: '2026-2027');
    StudentGrade selectedGrade = StudentGrade.firstSecondary;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('إضافة كورس جديد'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الكورس / المادة',
                            hintText: 'مثال: مدخل إلى لغة بايثون',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                            labelText: 'الوصف أو الملاحظات',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: yearController,
                          decoration: const InputDecoration(
                            labelText: 'العام الدراسي',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'الصف الدراسي المستهدف:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Text(
                                  StudentGrade.firstSecondary.toArabicDisplay(),
                                ),
                                selected:
                                    selectedGrade ==
                                    StudentGrade.firstSecondary,
                                onSelected: (val) {
                                  if (val)
                                    setDialogState(
                                      () =>
                                          selectedGrade =
                                              StudentGrade.firstSecondary,
                                    );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: Text(
                                  StudentGrade.secondSecondary
                                      .toArabicDisplay(),
                                ),
                                selected:
                                    selectedGrade ==
                                    StudentGrade.secondSecondary,
                                onSelected: (val) {
                                  if (val)
                                    setDialogState(
                                      () =>
                                          selectedGrade =
                                              StudentGrade.secondSecondary,
                                    );
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
                          final newCourse = CourseEntity(
                            id: '',
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            academicYear: yearController.text.trim(),
                            targetGrade: selectedGrade,
                            ownerAdminId: widget.user.id,
                          );
                          context.read<CourseBloc>().add(
                            CreateCourseRequested(newCourse),
                          );
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('إنشاء الكورس'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditCourseDialog(BuildContext context, CourseEntity course) {
    final titleController = TextEditingController(text: course.title);
    final descController = TextEditingController(text: course.description);
    final yearController = TextEditingController(text: course.academicYear);
    StudentGrade selectedGrade =
        course.targetGrade ?? StudentGrade.firstSecondary;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Text('تعديل بيانات الكورس'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'اسم الكورس',
                            hintText: 'مثال: مدخل إلى لغة بايثون',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                            labelText: 'الوصف أو الملاحظات',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: yearController,
                          decoration: const InputDecoration(
                            labelText: 'العام الدراسي',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'الصف الدراسي المستهدف:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: Text(
                                  StudentGrade.firstSecondary.toArabicDisplay(),
                                ),
                                selected:
                                    selectedGrade ==
                                    StudentGrade.firstSecondary,
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(
                                      () =>
                                          selectedGrade =
                                              StudentGrade.firstSecondary,
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: Text(
                                  StudentGrade.secondSecondary
                                      .toArabicDisplay(),
                                ),
                                selected:
                                    selectedGrade ==
                                    StudentGrade.secondSecondary,
                                onSelected: (val) {
                                  if (val) {
                                    setDialogState(
                                      () =>
                                          selectedGrade =
                                              StudentGrade.secondSecondary,
                                    );
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
                          final updated = course.copyWith(
                            title: titleController.text.trim(),
                            description: descController.text.trim(),
                            academicYear: yearController.text.trim(),
                            targetGrade: selectedGrade,
                          );
                          context.read<CourseBloc>().add(
                            UpdateCourseRequested(updated),
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم تعديل بيانات الكورس بنجاح'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      child: const Text('حفظ التعديلات'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showDeleteCourseDialog(BuildContext context, CourseEntity course) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.error),
                SizedBox(width: 8),
                Text('حذف الكورس'),
              ],
            ),
            content: Text(
              'هل أنت متأكد من رغبتك في حذف كورس "${course.title}"؟\nسيتم حذف الكورس وجميع الوحدات المرتبطة به نهائياً.',
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
                  context.read<CourseBloc>().add(
                    DeleteCourseRequested(course.id),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم حذف كورس "${course.title}" بنجاح'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                },
                child: const Text('تأكيد الحذف'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.user.isAdmin ? 'إدارة الكورسات والمناهج' : 'كورساتي التعليمية',
        ),
        actions: [
          if (widget.user.isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.upload_file_rounded),
              tooltip: 'استيراد كورس من ملف JSON',
              onPressed: () => _showImportJsonDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'إضافة كورس',
              onPressed: () => _showAddCourseDialog(context),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => context.read<AuthBloc>().add(SignOutRequested()),
          ),
        ],
      ),
      body: BlocBuilder<CourseBloc, CourseState>(
        builder: (context, state) {
          if (state is CourseLoading && state is! CourseLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CourseError) {
            return ErrorView(
              message: state.message,
              onRetry:
                  () => context.read<CourseBloc>().add(
                    const FetchCoursesRequested(),
                  ),
            );
          }

          if (state is CourseLoaded) {
            final courses =
                widget.user.isAdmin
                    ? (widget.user.role.isSuperAdmin
                        ? state.courses
                        : state.courses
                            .where((c) =>
                                c.ownerAdminId == widget.user.id ||
                                c.ownerAdminId == null)
                            .toList())
                    : widget.user.enrolledCourseIds.isNotEmpty
                    // Students with explicit enrollment: show only enrolled courses
                    ? state.courses
                        .where((c) => widget.user.enrolledCourseIds.contains(c.id))
                        .toList()
                    // Legacy students with no enrolledCourseIds: fall back to grade filter
                    : state.courses.where((c) {
                        if (widget.user.grade != null && c.targetGrade != null) {
                          return c.targetGrade == widget.user.grade;
                        }
                        return true;
                      }).toList();

            if (courses.isEmpty) {
              return EmptyStateView(
                icon: Icons.menu_book_outlined,
                title: 'لا توجد كورسات متاحة حالياً',
                message:
                    widget.user.isAdmin
                        ? 'ابدأ بإنشاء أول كورس دراسي للمرحلة الثانوية أو استيراده من ملف JSON جاهز.'
                        : 'لا توجد مقررات دراسية مخصصة لصفك الدراسي في الوقت الحالي.',
                actionLabel: widget.user.isAdmin ? 'إضافة كورس جديد' : null,
                onAction:
                    widget.user.isAdmin
                        ? () => _showAddCourseDialog(context)
                        : null,
                secondaryActionLabel:
                    widget.user.isAdmin ? 'استيراد كورس من JSON' : null,
                onSecondaryAction:
                    widget.user.isAdmin
                        ? () => _showImportJsonDialog(context)
                        : null,
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<CourseBloc>().add(const FetchCoursesRequested());
              },
              child: ResponsiveContent(
                maxWidth: 960,
                child: ListView.builder(
                  padding: context.screenPadding,
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return _CourseCard(
                      course: course,
                      isAdmin: widget.user.isAdmin,
                      onTap: () {
                        context.read<CourseBloc>().add(
                          SelectCourseRequested(course.id),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => CourseDetailScreen(
                                  course: course,
                                  user: widget.user,
                                ),
                          ),
                        );
                      },
                      onEdit: () => _showEditCourseDialog(context, course),
                      onDelete: () => _showDeleteCourseDialog(context, course),
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
}

class _CourseCard extends StatelessWidget {
  final CourseEntity course;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CourseCard({
    required this.course,
    required this.isAdmin,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.code_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                course.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (course.targetGrade != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.secondary.withAlpha(60),
                                  ),
                                ),
                                child: Text(
                                  course.targetGrade!.toArabicDisplay(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.academicYear,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tooltip: 'خيارات الكورس',
                      onSelected: (val) {
                        if (val == 'edit') {
                          onEdit?.call();
                        } else if (val == 'delete') {
                          onDelete?.call();
                        }
                      },
                      itemBuilder:
                          (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'تعديل الكورس',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
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
                    )
                  else
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
              if (course.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  course.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${course.unitCount} وحدات',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (isAdmin) ...[
                    const Icon(
                      Icons.people_outline,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${course.studentCount} طالب',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'مسجّل',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
