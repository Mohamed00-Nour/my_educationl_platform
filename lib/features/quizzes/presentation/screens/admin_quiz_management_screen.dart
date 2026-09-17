import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/performance_rating.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/quiz_entity.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../widgets/exam_submissions_sheet.dart';
import 'ai_import_screen.dart';
import 'question_bank_screen.dart';
import 'quiz_config_screen.dart';

class AdminQuizManagementScreen extends StatefulWidget {
  final UserEntity user;
  final String? courseId;
  final String? courseTitle;

  const AdminQuizManagementScreen({
    super.key,
    required this.user,
    this.courseId,
    this.courseTitle,
  });

  @override
  State<AdminQuizManagementScreen> createState() =>
      _AdminQuizManagementScreenState();
}

class _AdminQuizManagementScreenState extends State<AdminQuizManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<QuizEntity> _quizzes = [];
  List<Map<String, String>> _courses = [];
  late String _selectedCourseId;
  String _searchQuery = '';
  String _activeFilter = 'all'; // all, quiz, fullExam, published, draft, hasCode

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courseId ?? '';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load courses for course picker
      final firestore = FirebaseFirestore.instance;
      final coursesSnap =
          await firestore.collection(FirestoreCollections.courses).get();

      final filteredDocs = coursesSnap.docs.where((d) {
        if (widget.user.role.isSuperAdmin) return true;
        final owner = d.data()['ownerAdminId'] as String?;
        return owner == widget.user.id || owner == null;
      }).toList();

      final coursesList = filteredDocs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'title': (data['title'] as String?)?.trim().isNotEmpty == true
              ? (data['title'] as String).trim()
              : 'كورس بدون عنوان',
        };
      }).toList();

      _courses = coursesList;

      await _fetchQuizzes();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تحميل البيانات: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchQuizzes() async {
    try {
      final repo = getIt<QuizRepository>();
      final quizzes = await repo.getQuizzesForCourse(_selectedCourseId);

      // Sort newest first
      quizzes.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _quizzes = quizzes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'فشل في تحميل قائمة الاختبارات: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<QuizEntity> get _filteredQuizzes {
    return _quizzes.where((q) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          q.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          q.description.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      // Category / Status Filter
      switch (_activeFilter) {
        case 'quiz':
          return q.type == QuizType.quiz;
        case 'fullExam':
          return q.type == QuizType.fullExam;
        case 'published':
          return q.isPublished;
        case 'draft':
          return !q.isPublished;
        case 'hasCode':
          return q.requireStartCode;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _togglePublishStatus(QuizEntity quiz) async {
    try {
      final updated = quiz.copyWith(isPublished: !quiz.isPublished);
      final repo = getIt<QuizRepository>();
      await repo.updateQuiz(updated);

      setState(() {
        final index = _quizzes.indexWhere((q) => q.id == quiz.id);
        if (index != -1) {
          _quizzes[index] = updated;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isPublished
                ? 'تم نشر "${quiz.title}" للطلاب بنجاح.'
                : 'تم تحويل "${quiz.title}" إلى مسودة مخفية.',
          ),
          backgroundColor:
              updated.isPublished ? AppColors.success : AppColors.info,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في تعديل حالة النشر: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmDeleteQuiz(QuizEntity quiz) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('حذف الاختبار'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف "${quiz.title}" نهائياً؟ لن يتمكن الطلاب من تقديم الاختبار بعد الحذف.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = getIt<QuizRepository>();
      await repo.deleteQuiz(quiz.id);

      setState(() {
        _quizzes.removeWhere((q) => q.id == quiz.id);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف الاختبار "${quiz.title}" بنجاح.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف الاختبار: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showCreateQuizOptions() {
    showAdaptiveModal(
      context: context,
      maxWidth: 520,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إنشاء اختبار أو امتحان جديد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'اختر الطريقة المناسبة لإعداد ونشر الاختبار',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // Option 1: AI / JSON Import
            _DuolingoActionTile(
              title: 'استيراد وتوليد بالذكاء الاصطناعي',
              subtitle: 'استيراد أسئلة عبر كود JSON أو التوليد الفوري للمعاينة والنشر',
              icon: Icons.auto_awesome,
              color: AppColors.secondary,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AIImportScreen(
                      courseId: _selectedCourseId.isNotEmpty
                          ? _selectedCourseId
                          : null,
                    ),
                  ),
                ).then((_) => _fetchQuizzes());
              },
            ),
            const SizedBox(height: 12),

            // Option 2: Question Bank
            _DuolingoActionTile(
              title: 'اختيار من بنك الأسئلة',
              subtitle: 'تصفح الأسئلة الجاهزة واختيار مجموعة لإنشاء اختبار منها',
              icon: Icons.inventory_2_outlined,
              color: AppColors.accent,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionBankScreen(
                      courseId: _selectedCourseId.isNotEmpty
                          ? _selectedCourseId
                          : null,
                    ),
                  ),
                ).then((_) => _fetchQuizzes());
              },
            ),
            const SizedBox(height: 12),

            // Option 3: Manual Questions & Answers Quiz
            _DuolingoActionTile(
              title: 'إنشاء وإضافة الأسئلة يدوياً',
              subtitle: 'كتابة الأسئلة والخيارات وتحديد الإجابات الصحيحة وإعدادات الاختبار',
              icon: Icons.edit_note_rounded,
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizConfigScreen(
                      courseId: _selectedCourseId.isNotEmpty
                          ? _selectedCourseId
                          : (_courses.isNotEmpty ? _courses.first['id']! : ''),
                    ),
                  ),
                ).then((_) => _fetchQuizzes());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إدارة الاختبارات والامتحانات'),
            if (widget.courseTitle != null)
              Text(
                widget.courseTitle!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchQuizzes();
            },
          ),
        ],
      ),
      floatingActionButton: AppButton(
        label: 'إنشاء اختبار جديد',
        icon: Icons.add,
        backgroundColor: AppColors.primary,
        width: 195,
        height: 52,
        borderRadius: 26,
        bevelHeight: 5.0,
        fontSize: 15,
        onPressed: _showCreateQuizOptions,
      ),
      body: ResponsiveContent(
        maxWidth: 1050,
        child: Column(
          children: [
            // Course Selector & Search Filter Bar
            Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                // Course Dropdown Selector
                if (widget.courseId == null && _courses.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'الكورس المستهدف:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCourseId,
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('جميع الكورسات'),
                              ),
                              ..._courses.map(
                                (c) => DropdownMenuItem(
                                  value: c['id']!,
                                  child: Text(
                                    c['title']!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null && val != _selectedCourseId) {
                                setState(() {
                                  _selectedCourseId = val;
                                  _isLoading = true;
                                });
                                _fetchQuizzes();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'البحث باسم الاختبار أو وصفه...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _searchQuery = ''),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 10),

                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterTab(
                        label: 'الكل (${_quizzes.length})',
                        isSelected: _activeFilter == 'all',
                        onTap: () => setState(() => _activeFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label:
                            'كويزات (${_quizzes.where((q) => q.type == QuizType.quiz).length})',
                        isSelected: _activeFilter == 'quiz',
                        onTap: () => setState(() => _activeFilter = 'quiz'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label:
                            'امتحانات شاملة (${_quizzes.where((q) => q.type == QuizType.fullExam).length})',
                        isSelected: _activeFilter == 'fullExam',
                        onTap: () => setState(() => _activeFilter = 'fullExam'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label:
                            'منشور (${_quizzes.where((q) => q.isPublished).length})',
                        isSelected: _activeFilter == 'published',
                        onTap: () => setState(() => _activeFilter = 'published'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label:
                            'مسودة (${_quizzes.where((q) => !q.isPublished).length})',
                        isSelected: _activeFilter == 'draft',
                        onTap: () => setState(() => _activeFilter = 'draft'),
                      ),
                      const SizedBox(width: 8),
                      _FilterTab(
                        label:
                            'برمز سري (${_quizzes.where((q) => q.requireStartCode).length})',
                        isSelected: _activeFilter == 'hasCode',
                        onTap: () => setState(() => _activeFilter = 'hasCode'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Quizzes List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.error),
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                label: 'إعادة المحاولة',
                                onPressed: () {
                                  setState(() => _isLoading = true);
                                  _fetchQuizzes();
                                },
                                backgroundColor: AppColors.primary,
                                height: 44,
                                borderRadius: 12,
                                bevelHeight: 3.5,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredQuizzes.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.quiz_outlined,
                                      size: 44,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'لا توجد اختبارات مطابقة',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'يمكنك إنشاء اختبار جديد بنقرة زر عبر الزر أدناه.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AppButton(
                                    label: 'إنشاء اختبار الآن',
                                    icon: Icons.add,
                                    backgroundColor: AppColors.primary,
                                    width: 200,
                                    height: 48,
                                    borderRadius: 14,
                                    bevelHeight: 4.0,
                                    onPressed: _showCreateQuizOptions,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                            itemCount: _filteredQuizzes.length,
                            itemBuilder: (context, index) {
                              final quiz = _filteredQuizzes[index];
                              return _AdminQuizCard(
                                quiz: quiz,
                                onTogglePublish: () =>
                                    _togglePublishStatus(quiz),
                                onEdit: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuizConfigScreen(
                                        existingQuiz: quiz,
                                        courseId: quiz.courseId,
                                      ),
                                    ),
                                  ).then((_) => _fetchQuizzes());
                                },
                                onViewSubmissions: () =>
                                    ExamSubmissionsSheet.show(context, quiz),
                                onDelete: () => _confirmDeleteQuiz(quiz),
                              );
                            },
                          ),
          ),
        ],
      ),
    ),
  );
}
}

class _AdminQuizCard extends StatelessWidget {
  final QuizEntity quiz;
  final VoidCallback onTogglePublish;
  final VoidCallback onEdit;
  final VoidCallback onViewSubmissions;
  final VoidCallback onDelete;

  const _AdminQuizCard({
    required this.quiz,
    required this.onTogglePublish,
    required this.onEdit,
    required this.onViewSubmissions,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExam = quiz.isFullExam;
    final themeColor = isExam ? AppColors.accent : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: quiz.isPublished
              ? themeColor.withAlpha(40)
              : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badges and Action Menu
            Row(
              children: [
                // Assessment Type Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: themeColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isExam ? 'امتحان شامل' : 'كويز قصير',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: themeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Publish Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (quiz.isPublished
                            ? AppColors.success
                            : AppColors.textSecondary)
                        .withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        quiz.isPublished
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 12,
                        color: quiz.isPublished
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        quiz.isPublished ? 'منشور للطلاب' : 'مسودة مخفية',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: quiz.isPublished
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // More Menu Button
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: 'خيارات الاختبار',
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'toggle_publish') onTogglePublish();
                    if (val == 'submissions') onViewSubmissions();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('تعديل الإعدادات والرمز',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_publish',
                      child: Row(
                        children: [
                          Icon(
                            quiz.isPublished
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            quiz.isPublished
                                ? 'إلغاء النشر (تحويل لمسودة)'
                                : 'نشر الاختبار للطلاب',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'submissions',
                      child: Row(
                        children: [
                          Icon(Icons.insights_outlined,
                              size: 16, color: AppColors.accent),
                          SizedBox(width: 8),
                          Text('نتائج وتسليمات الطلاب',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 16, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('حذف الاختبار',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              quiz.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (quiz.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quiz.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Start Code Information Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: quiz.requireStartCode
                    ? AppColors.primaryLight.withAlpha(20)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: quiz.requireStartCode
                      ? AppColors.primary.withAlpha(40)
                      : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    quiz.requireStartCode
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    size: 16,
                    color: quiz.requireStartCode
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    quiz.requireStartCode
                        ? 'رمز بدء الاختبار: ${quiz.startCode ?? 'محمي بتشفير آمن'}'
                        : 'بدون رمز بدء (متاح فوراً للطلاب)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: quiz.requireStartCode
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: quiz.requireStartCode
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Specs Row
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _SpecItem(
                  icon: Icons.format_list_numbered,
                  text: '${quiz.questions.length} أسئلة',
                ),
                _SpecItem(
                  icon: Icons.timer_outlined,
                  text: '${quiz.durationMinutes} دقيقة',
                ),
                _SpecItem(
                  icon: Icons.grade_outlined,
                  text:
                      '${quiz.totalMarks} درجات • النجاح من ${PerformanceRating.passThreshold.toStringAsFixed(0)}%',
                ),
                _SpecItem(
                  icon: Icons.repeat_outlined,
                  text: '${quiz.maxAttempts} محاولات',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Bottom Actions Bar
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AppButton(
                    label: 'نتائج وتسليمات الطلاب',
                    icon: Icons.analytics_outlined,
                    backgroundColor:
                        isExam ? AppColors.accent : AppColors.secondary,
                    height: 40,
                    borderRadius: 12,
                    bevelHeight: 3.5,
                    fontSize: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onViewSubmissions,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'تعديل',
                    icon: Icons.edit_outlined,
                    isOutlined: true,
                    textColor: AppColors.textPrimary,
                    height: 40,
                    borderRadius: 12,
                    bevelHeight: 3.5,
                    fontSize: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onEdit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SpecItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _FilterTab extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FilterTab> createState() => _FilterTabState();
}

class _FilterTabState extends State<_FilterTab> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSel = widget.isSelected;
    final bg = isSel ? AppColors.primary : AppColors.surface;
    final bevel = isSel ? AppColors.primaryDark : AppColors.borderDark;
    final text = isSel ? const Color(0xFF131F24) : AppColors.textSecondary;
    final pressOffset = _isPressed ? 2.5 : 0.0;
    const double bevelHeight = 3.5;
    const double height = 36.0;
    final double faceHeight = height - bevelHeight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 3D Bevel Layer
            Positioned(
              top: bevelHeight,
              left: 0,
              right: 0,
              height: faceHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: bevel,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            // Tactile Face Layer (Non-positioned child gives Stack finite intrinsic width)
            AnimatedSlide(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOut,
              offset: Offset(0, _isPressed ? (pressOffset / faceHeight) : 0.0),
              child: Container(
                height: faceHeight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: isSel
                      ? null
                      : Border.all(color: AppColors.border, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Cairo',
                    color: text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuolingoActionTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DuolingoActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_DuolingoActionTile> createState() => _DuolingoActionTileState();
}

class _DuolingoActionTileState extends State<_DuolingoActionTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final pressOffset = _isPressed ? 3.0 : 0.0;
    const double bevelHeight = 4.0;
    const double height = 76.0;
    final double faceHeight = height - bevelHeight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Bottom 3D Bevel
            Positioned(
              top: bevelHeight,
              left: 0,
              right: 0,
              height: faceHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Tactile Top Face (Non-positioned child)
            AnimatedSlide(
              duration: const Duration(milliseconds: 60),
              curve: Curves.easeOut,
              offset: Offset(0, _isPressed ? (pressOffset / faceHeight) : 0.0),
              child: Container(
                height: faceHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.color.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
