import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../../../core/utils/url_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../quizzes/domain/entities/exam_attempt_entity.dart';
import '../../../quizzes/domain/entities/local_attempt_entity.dart';
import '../../../quizzes/domain/entities/quiz_entity.dart';
import '../../../quizzes/domain/repositories/quiz_repository.dart';
import '../../../quizzes/presentation/screens/exam_result_screen.dart';
import '../../../quizzes/presentation/screens/exam_taking_screen.dart';
import '../../../quizzes/presentation/widgets/start_code_dialog.dart';
import '../../../notifications/presentation/widgets/push_notification_fields.dart';
import '../../domain/entities/lesson_entity.dart';
import '../../domain/entities/lesson_material_entity.dart';
import '../../domain/services/material_type_resolver.dart';
import '../bloc/course_bloc.dart';
import 'pdf_viewer_screen.dart';
import 'video_player_screen.dart';
import 'html_viewer_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final LessonEntity lesson;
  final UserEntity user;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
    required this.user,
  });

  static IconData getMaterialIcon(CourseMaterialType type) {
    switch (type) {
      case CourseMaterialType.ministryBook:
        return Icons.menu_book_rounded;
      case CourseMaterialType.slides:
        return Icons.slideshow_rounded;
      case CourseMaterialType.summaryPdf:
        return Icons.summarize_rounded;
      case CourseMaterialType.video:
        return Icons.play_circle_fill_rounded;
      case CourseMaterialType.pdf:
        return Icons.picture_as_pdf_rounded;
      case CourseMaterialType.interactiveHtml:
        return Icons.code_rounded;
      case CourseMaterialType.link:
        return Icons.link_rounded;
    }
  }

  static Color getMaterialColor(CourseMaterialType type) {
    switch (type) {
      case CourseMaterialType.ministryBook:
        return AppColors.primary;
      case CourseMaterialType.slides:
        return Colors.deepPurple;
      case CourseMaterialType.summaryPdf:
        return Colors.teal;
      case CourseMaterialType.video:
        return Colors.red;
      case CourseMaterialType.pdf:
        return Colors.deepOrange;
      case CourseMaterialType.interactiveHtml:
        return Colors.cyan;
      case CourseMaterialType.link:
        return AppColors.info;
    }
  }

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure real-time streaming is active for this lesson's course
    context.read<CourseBloc>().add(StreamCourseDetailsRequested(widget.lesson.courseId));
  }

  Future<void> _showMaterialDialog(
    BuildContext context,
    LessonEntity currentLesson, {
    LessonMaterialEntity? material,
  }) async {
    final isEditing = material != null;
    final titleController = TextEditingController(text: material?.title ?? '');
    final urlController = TextEditingController(text: material?.url ?? '');
    final startPageController = TextEditingController(
      text: material?.startPage?.toString() ?? '',
    );
    final endPageController = TextEditingController(
      text: material?.endPage?.toString() ?? '',
    );
    final notesController = TextEditingController(text: material?.notes ?? '');
    CourseMaterialType selectedType = material?.type ?? CourseMaterialType.link;
    String? formError;
    final notificationDraft = PushNotificationDraft(
      defaultTitle: 'ملحق تعليمي جديد',
      defaultBody: 'تمت إضافة مادة تعليمية جديدة إلى درس ${currentLesson.title}.',
    );
    ModalRoute<dynamic>? dialogRoute;

    await showDialog(
      context: context,
      builder: (ctx) {
        dialogRoute ??= ModalRoute.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isEditing
                ? 'تعديل المادة التعليمية أو الملحق'
                : 'إضافة مادة تعليمية أو ملحق',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان المادة / الملحق *',
                    hintText: 'مثال: كتاب الوزارة - صفحات بايثون',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CourseMaterialType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'تصنيف المادة (تلميح فقط)',
                    helperText: 'سيحدد التطبيق طريقة الفتح تلقائياً من الملف أو الرابط',
                  ),
                  items: CourseMaterialType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(LessonDetailScreen.getMaterialIcon(type), size: 18, color: LessonDetailScreen.getMaterialColor(type)),
                          const SizedBox(width: 8),
                          Text(type.toArabicDisplay(), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  onChanged: (value) {
                    final detected = MaterialTypeResolver.detect(value);
                    setDialogState(() {
                      formError = null;
                      if (detected != null) selectedType = detected;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'رابط الملف أو الصفحة (URL) *',
                    hintText: 'https://drive.google.com/...',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withAlpha(70)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.cloud_outlined, size: 18, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ترفع جميع الملحقات إلى Google Drive. بعد الرفع اجعل الصلاحية '
                          '«أي شخص لديه الرابط»، ثم الصق رابط المشاركة هنا.',
                          style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_to_drive_rounded, size: 18),
                    label: const Text('فتح Google Drive لرفع الملف'),
                    onPressed: () async {
                      final opened = await UrlService.openExternalUrl(
                        'https://drive.google.com/drive/my-drive',
                      );
                      if (!opened && ctx.mounted) {
                        setDialogState(() {
                          formError = 'تعذر فتح Google Drive على هذا الجهاز.';
                        });
                      }
                    },
                  ),
                ),
                if (!isEditing)
                  PushNotificationFields(draft: notificationDraft),
                if (formError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    formError!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                if (selectedType == CourseMaterialType.ministryBook ||
                    selectedType == CourseMaterialType.pdf ||
                    selectedType == CourseMaterialType.summaryPdf) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startPageController,
                          decoration: const InputDecoration(
                            labelText: 'من صفحة',
                            hintText: '15',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endPageController,
                          decoration: const InputDecoration(
                            labelText: 'إلى صفحة',
                            hintText: '22',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات إضافية (اختياري)',
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
                final rawUrl = urlController.text.trim();
                if (title.isEmpty) {
                  setDialogState(() => formError = 'يرجى كتابة عنوان الملحق.');
                  return;
                }
                if (!UrlService.isShareableWebUrl(rawUrl)) {
                  setDialogState(() {
                    formError = 'يرجى إدخال رابط مشاركة صحيح يبدأ بـ https://. '
                        'لا يمكن مشاركة مسار ملف محلي مع الطلاب.';
                  });
                  return;
                }
                if (!isEditing) {
                  final notificationError = notificationDraft.validate();
                  if (notificationError != null) {
                    setDialogState(() => formError = notificationError);
                    return;
                  }
                }

                final url = UrlService.normalizeUrl(rawUrl);
                {
                  final startPage = int.tryParse(startPageController.text.trim());
                  final endPage = int.tryParse(endPageController.text.trim());
                  final notes = notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : null;

                  final savedMaterial = LessonMaterialEntity(
                    id: material?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    type: MaterialTypeResolver.typeForStorage(
                      url,
                      hint: selectedType,
                    ),
                    url: url,
                    startPage: startPage,
                    endPage: endPage,
                    notes: notes,
                  );

                  final updatedMaterials = List<LessonMaterialEntity>.from(
                    currentLesson.materials,
                  );
                  if (isEditing) {
                    final materialIndex = updatedMaterials.indexWhere(
                      (item) => item.id == material.id,
                    );
                    if (materialIndex >= 0) {
                      updatedMaterials[materialIndex] = savedMaterial;
                    } else {
                      setDialogState(() {
                        formError = 'تعذر العثور على الملحق. أغلق النافذة وحاول مرة أخرى.';
                      });
                      return;
                    }
                  } else {
                    updatedMaterials.add(savedMaterial);
                  }
                  final updatedLesson = currentLesson.copyWith(materials: updatedMaterials);

                  context.read<CourseBloc>().add(
                    UpdateLessonRequested(
                      updatedLesson,
                      notification: isEditing
                          ? null
                          : notificationDraft.buildRequest(
                              courseId: currentLesson.courseId,
                              contentType: 'material',
                              contentId: savedMaterial.id,
                              lessonId: currentLesson.id,
                            ),
                    ),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة'),
            ),
          ],
          ),
        );
      },
    );

    // showDialog completes when pop starts. Wait until the reverse transition
    // removes the dialog widgets before disposing their controllers.
    await dialogRoute?.completed;
    titleController.dispose();
    urlController.dispose();
    startPageController.dispose();
    endPageController.dispose();
    notesController.dispose();
    notificationDraft.dispose();
  }

  void _confirmDeleteMaterial(
    BuildContext context,
    LessonEntity currentLesson,
    LessonMaterialEntity material,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة الملحق'),
        content: Text('هل أنت متأكد من رغبتك في إزالة ملحق "${material.title}" من هذا الدرس؟'),
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
              final updatedMaterials = List<LessonMaterialEntity>.from(currentLesson.materials)
                ..removeWhere((m) => m.id == material.id || (m.title == material.title && m.url == material.url));
              final updatedLesson = currentLesson.copyWith(materials: updatedMaterials);
              context.read<CourseBloc>().add(UpdateLessonRequested(updatedLesson));
              Navigator.pop(ctx);
            },
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CourseBloc, CourseState>(
      builder: (context, state) {
        // Read latest lesson state if present in CourseLoaded
        LessonEntity activeLesson = widget.lesson;
        if (state is CourseLoaded) {
          final unitLessons = state.lessonsByUnit[widget.lesson.unitId] ?? [];
          final match = unitLessons.where((l) => l.id == widget.lesson.id);
          if (match.isNotEmpty) {
            activeLesson = match.first;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(activeLesson.title),
            actions: [
              if (widget.user.isAdmin)
                IconButton(
                  icon: const Icon(Icons.add_link_rounded),
                  tooltip: 'إضافة ملحق أو مادة تعليمية',
                  onPressed: () => _showMaterialDialog(context, activeLesson),
                ),
            ],
          ),
          body: ResponsiveContent(
            maxWidth: 900,
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<CourseBloc>().add(StreamCourseDetailsRequested(widget.lesson.courseId));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.screenPadding,
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Description Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                activeLesson.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            if (!activeLesson.isPublished)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warningLight.withAlpha(60),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'مسودة (مخفي)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (activeLesson.bookStartPage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_stories_rounded, size: 15, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'كتاب الوزارة المدرسي: صـ ${activeLesson.bookStartPage}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (activeLesson.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            activeLesson.description,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Lesson Materials Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'المواد التعليمية والمذكرات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.user.isAdmin)
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('إضافة ملحق'),
                        onPressed: () => _showMaterialDialog(context, activeLesson),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (activeLesson.materials.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: AppColors.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.user.isAdmin
                                  ? 'لا توجد مذكرات أو ملفات مرفقة لهذا الدرس. يمكنك إضافة كتاب الوزارة، ملخصات، شرائح، أو فيديوهات عبر الزر أعلاه.'
                                  : 'لا توجد مذكرات أو ملفات مرفقة لهذا الدرس حالياً.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...activeLesson.materials.map(
                    (m) => _MaterialCard(
                      material: m,
                      isAdmin: widget.user.isAdmin,
                      onEdit: () => _showMaterialDialog(
                        context,
                        activeLesson,
                        material: m,
                      ),
                      onDelete: () => _confirmDeleteMaterial(context, activeLesson, m),
                    ),
                  ),

                // Teacher Notes
                if (activeLesson.notes != null && activeLesson.notes!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'ملاحظات وتوجيهات المعلم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: AppColors.warningLight.withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.warning.withAlpha(60)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            color: AppColors.warning,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              activeLesson.notes!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Quiz Section
                if (activeLesson.quizId != null) ...[
                  const SizedBox(height: 28),
                  _LessonQuizCard(
                    lesson: activeLesson,
                    user: widget.user,
                  ),
                ],
              ],
            ),
            ),
          ),
        ),
      );
    },
  );
}
}

class _MaterialCard extends StatelessWidget {
  final LessonMaterialEntity material;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MaterialCard({
    required this.material,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
  });

  bool get _isCloudPreview => UrlService.isGoogleHostedFileUrl(material.url);

  bool get _isPdf {
    return MaterialTypeResolver.detect(material.url) == CourseMaterialType.pdf;
  }

  bool get _isVideo {
    return MaterialTypeResolver.detect(material.url) == CourseMaterialType.video;
  }

  bool get _isHtml {
    return MaterialTypeResolver.detect(material.url) ==
        CourseMaterialType.interactiveHtml;
  }

  void _openMaterial(BuildContext context) {
    // Drive share URLs are web pages, not direct PDF/video URLs. Google preview
    // streams large files without downloading the entire file into the app.
    if (_isCloudPreview) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HtmlViewerScreen(material: material),
        ),
      );
    } else if (_isPdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(material: material),
        ),
      );
    } else if (_isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(material: material),
        ),
      );
    } else if (_isHtml) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HtmlViewerScreen(material: material),
        ),
      );
    } else {
      // Normal web pages and unknown share providers are attempted in-app;
      // the viewer always exposes an external-browser fallback.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HtmlViewerScreen(material: material),
        ),
      );
    }
  }

  IconData _getActionIcon() {
    if (_isCloudPreview) return Icons.visibility_outlined;
    if (_isPdf) return Icons.visibility_outlined;
    if (_isVideo) return Icons.play_circle_fill_rounded;
    if (_isHtml) return Icons.code_rounded;
    return Icons.open_in_new;
  }

  String _getActionTooltip() {
    if (_isCloudPreview) return 'معاينة الملف السحابي';
    if (_isPdf) return 'عرض وقراءة المستند';
    if (_isVideo) return 'تشغيل الفيديو';
    if (_isHtml) return 'عرض النشاط التفاعلي';
    return 'فتح الرابط داخل التطبيق';
  }

  @override
  Widget build(BuildContext context) {
    final color = LessonDetailScreen.getMaterialColor(material.type);
    final icon = LessonDetailScreen.getMaterialIcon(material.type);

    String pageInfo = '';
    if (material.startPage != null) {
      if (material.endPage != null && material.endPage != material.startPage) {
        pageInfo = 'صفحات: ${material.startPage} - ${material.endPage}';
      } else {
        pageInfo = 'صفحة: ${material.startPage}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => _openMaterial(context),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          material.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  material.type.toArabicDisplay(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (pageInfo.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  const Text('•', style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  Text(
                    pageInfo,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
            if (material.notes != null && material.notes!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                material.notes!,
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_getActionIcon(), size: 22, color: color),
              tooltip: _getActionTooltip(),
              onPressed: () => _openMaterial(context),
            ),
            if (isAdmin && onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.info),
                tooltip: 'تعديل الملحق',
                onPressed: onEdit,
              ),
            if (isAdmin && onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                tooltip: 'إزالة الملحق',
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonQuizCard extends StatefulWidget {
  final LessonEntity lesson;
  final UserEntity user;

  const _LessonQuizCard({
    required this.lesson,
    required this.user,
  });

  @override
  State<_LessonQuizCard> createState() => _LessonQuizCardState();
}

class _LessonQuizCardState extends State<_LessonQuizCard> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _isCompleted = false;
  bool _hasPassed = false;
  QuizEntity? _quiz;
  ExamAttemptEntity? _latestAttempt;

  @override
  void initState() {
    super.initState();
    _checkStatusAndAutoDownload();
  }

  Future<void> _checkStatusAndAutoDownload() async {
    final quizId = widget.lesson.quizId;
    if (quizId == null) return;
    final repo = getIt<QuizRepository>();

    // Check cached offline availability
    final isCached = await repo.isQuizAvailableOffline(quizId);
    if (mounted) {
      setState(() => _isDownloaded = isCached);
    }

    try {
      final quiz = await repo.getQuizById(quizId);
      if (quiz == null) return;
      _quiz = quiz;

      final attempts = await repo.getAttemptsForStudent(
        widget.user.id,
        courseId: widget.lesson.courseId,
      );
      final quizAttempts = attempts.where((a) => a.examId == quizId).toList();

      final hasPassed = quizAttempts.any(
        (a) => PerformanceRating.fromPercentage(a.percentage).isSuccessful,
      );
      final hasConsumedRetries = quizAttempts.length >= quiz.maxAttempts;
      final isDeadlinePassed =
          quiz.availableUntil != null &&
          DateTime.now().isAfter(quiz.availableUntil!);

      final isCompleted =
          hasPassed ||
          (quizAttempts.isNotEmpty && (hasConsumedRetries || isDeadlinePassed));

      ExamAttemptEntity? latestAttempt;
      if (quizAttempts.isNotEmpty) {
        final sorted = List<ExamAttemptEntity>.from(quizAttempts)
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        latestAttempt = sorted.first;
      }

      if (mounted) {
        setState(() {
          _hasPassed = hasPassed;
          _isCompleted = isCompleted;
          _latestAttempt = latestAttempt;
        });
      }

      // Automatically download and cache quiz locally when student is online and quiz is available
      if (!isCached && quiz.isPublished && !isCompleted) {
        if (mounted) {
          setState(() => _isDownloading = true);
        }
        await repo.cacheQuizForOffline(quiz);
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _downloadForOffline() async {
    final quizId = widget.lesson.quizId;
    if (quizId == null) return;
    setState(() => _isDownloading = true);
    try {
      final repo = getIt<QuizRepository>();
      final quiz = _quiz ?? await repo.getQuizById(quizId);
      if (quiz != null) {
        _quiz = quiz;
        await repo.cacheQuizForOffline(quiz);
        if (mounted) {
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
          });
          final hasCode = quiz.requireStartCode;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasCode
                    ? 'تم تحميل الاختبار ورمز البدء بنجاح للعمل بدون إنترنت!'
                    : 'تم تحميل وتجهيز الاختبار للعمل بدون إنترنت بالكامل!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isDownloading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر تحميل بيانات الاختبار.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _startQuiz() async {
    final quizId = widget.lesson.quizId!;
    final repo = getIt<QuizRepository>();
    final quiz = _quiz ?? await repo.getQuizById(quizId);

    if (quiz == null) return;

    // If completed or retries consumed, only show details and do not start over!
    if (_isCompleted && _latestAttempt != null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamResultScreen(
            attempt: _latestAttempt!,
            quiz: quiz,
          ),
        ),
      );
      _checkStatusAndAutoDownload();
      return;
    }

    final active = await repo.loadActiveAttemptLocally(
      quizId,
      widget.user.id,
    );
    if (active != null && active.status == AttemptSyncStatus.inProgress) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamTakingScreen(
            quizId: quizId,
            user: widget.user,
          ),
        ),
      );
      _checkStatusAndAutoDownload();
      return;
    }

    String? validatedCode;
    if (quiz.requireStartCode) {
      if (!mounted) return;
      final enteredCode = await StartCodeDialog.show(
        context,
        quiz,
      );
      if (enteredCode == null) return;
      validatedCode = enteredCode;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamTakingScreen(
          quizId: quizId,
          user: widget.user,
          startCode: validatedCode,
        ),
      ),
    );
    _checkStatusAndAutoDownload();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryLight.withAlpha(15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primaryLight.withAlpha(60)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_isCompleted && _latestAttempt != null && _quiz != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExamResultScreen(
                  attempt: _latestAttempt!,
                  quiz: _quiz!,
                ),
              ),
            ).then((_) => _checkStatusAndAutoDownload());
          } else {
            _startQuiz();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.quiz_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _quiz?.title ?? 'اختبار وتقييم الدرس',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _quiz != null
                              ? '${_quiz!.durationMinutes} دقيقة • ${_quiz!.questions.length} سؤال • ${_quiz!.totalMarks} درجة'
                              : 'اختبر مدى فهمك واستيعابك لموضوع هذا الدرس',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isCompleted && !_isDownloaded) ...[
                    const SizedBox(width: 8),
                    if (_isDownloading)
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
                        tooltip: 'تحميل الاختبار ورمز البدء للعمل بدون إنترنت',
                        onPressed: _downloadForOffline,
                      ),
                  ],
                ],
              ),
              if ((_quiz?.requireStartCode ?? false) ||
                  _isCompleted ||
                  _isDownloaded ||
                  _isDownloading) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_quiz?.requireStartCode ?? false)
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
                    if (_isCompleted)
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
                              _hasPassed ? 'تم الإجتياز بنجاح' : 'تم الإجتياز',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            if (_latestAttempt != null && _quiz != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${_latestAttempt!.score}/${_quiz!.totalMarks}',
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
                    else if (_isDownloaded)
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
                    else if (_isDownloading)
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
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_isCompleted && _latestAttempt != null && _quiz != null)
                    Expanded(
                      child: AppButton(
                        label: 'عرض تفاصيل ونتيجة الاختبار',
                        icon: Icons.visibility_outlined,
                        backgroundColor: AppColors.surfaceVariant,
                        textColor: AppColors.primaryLight,
                        bevelHeight: 3,
                        height: 46,
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExamResultScreen(
                                attempt: _latestAttempt!,
                                quiz: _quiz!,
                              ),
                            ),
                          );
                          _checkStatusAndAutoDownload();
                        },
                      ),
                    )
                  else ...[
                    Expanded(
                      child: AppButton(
                        label: 'بدء اختبار الدرس الآن',
                        icon: Icons.play_arrow_rounded,
                        onPressed: _startQuiz,
                      ),
                    ),
                    if (!_isDownloaded) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_rounded),
                        tooltip: 'تحميل للعمل بدون إنترنت',
                        onPressed: _isDownloading ? null : _downloadForOffline,
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
  }
}
