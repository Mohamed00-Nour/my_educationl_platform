import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/student_management_repository.dart';
import '../widgets/edit_student_dialog.dart';
import 'student_exam_management_screen.dart';

class StudentManagementScreen extends StatefulWidget {
  final UserEntity admin;

  const StudentManagementScreen({super.key, required this.admin});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final _searchController = TextEditingController();
  late final StudentManagementRepository _repository;
  List<ManagedStudent> _students = const [];
  List<ManagedCourse> _courses = const [];
  bool _loading = true;
  String? _error;
  StudentGrade? _gradeFilter;
  String? _courseFilter;

  @override
  void initState() {
    super.initState();
    _repository = StudentManagementRepository();
    _searchController.addListener(_refreshFilters);
    _load();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshFilters)
      ..dispose();
    super.dispose();
  }

  void _refreshFilters() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.loadStudents(widget.admin),
        _repository.loadCourses(widget.admin),
      ]);
      if (!mounted) return;
      setState(() {
        _students = results[0] as List<ManagedStudent>;
        _courses = results[1] as List<ManagedCourse>;
        if (_courseFilter != null &&
            !_courses.any((course) => course.id == _courseFilter)) {
          _courseFilter = null;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الطلاب. تأكد من الاتصال وحاول مرة أخرى.\n$error';
        _loading = false;
      });
    }
  }

  List<ManagedStudent> get _filteredStudents {
    final search = _searchController.text.trim().toLowerCase();
    return _students.where((student) {
      final matchesSearch =
          search.isEmpty ||
          student.displayName.toLowerCase().contains(search) ||
          student.email.toLowerCase().contains(search);
      final matchesGrade =
          _gradeFilter == null || student.grade == _gradeFilter;
      final matchesCourse =
          _courseFilter == null ||
          student.enrolledCourseIds.contains(_courseFilter);
      return matchesSearch && matchesGrade && matchesCourse;
    }).toList();
  }

  List<ManagedCourse> _studentCourses(ManagedStudent student) {
    return _courses
        .where((course) => student.enrolledCourseIds.contains(course.id))
        .toList();
  }

  Future<void> _editStudent(ManagedStudent student) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => EditStudentDialog(
            student: student,
            courses: _courses,
            repository: _repository,
          ),
    );
    if (changed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ بيانات الطالب بنجاح.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _load();
    }
  }

  void _manageExams(ManagedStudent student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => StudentExamManagementScreen(
              student: student,
              courses: _courses,
              repository: _repository,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _filteredStudents;
    final enrolledCount =
        _students
            .where((student) => student.enrolledCourseIds.isNotEmpty)
            .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلاب'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'تحديث البيانات',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ResponsiveContent(
          maxWidth: 1100,
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: context.screenPadding,
                    children: [
                      const SizedBox(height: 100),
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 56,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 14),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ),
                    ],
                  )
                  : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: context.screenPadding,
                    children: [
                      _ManagementHeader(
                        totalStudents: _students.length,
                        enrolledStudents: enrolledCount,
                      ),
                      const SizedBox(height: 16),
                      _FiltersCard(
                        searchController: _searchController,
                        gradeFilter: _gradeFilter,
                        courseFilter: _courseFilter,
                        courses: _courses,
                        onGradeChanged:
                            (value) => setState(() => _gradeFilter = value),
                        onCourseChanged:
                            (value) => setState(() => _courseFilter = value),
                        onClear: () {
                          _searchController.clear();
                          setState(() {
                            _gradeFilter = null;
                            _courseFilter = null;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text(
                            'قائمة الطلاب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${filteredStudents.length} طالب',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (filteredStudents.isEmpty)
                        const SizedBox(
                          height: 330,
                          child: EmptyStateView(
                            icon: Icons.people_outline,
                            title: 'لا يوجد طلاب مطابقون',
                            message: 'غيّر البحث أو عوامل التصفية لعرض الطلاب.',
                          ),
                        )
                      else
                        ...filteredStudents.map(
                          (student) => _StudentCard(
                            student: student,
                            courses: _studentCourses(student),
                            onEdit: () => _editStudent(student),
                            onManageExams: () => _manageExams(student),
                          ),
                        ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _ManagementHeader extends StatelessWidget {
  final int totalStudents;
  final int enrolledStudents;

  const _ManagementHeader({
    required this.totalStudents,
    required this.enrolledStudents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.manage_accounts_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'التحكم الكامل في بيانات الطلاب',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'تعديل الاسم والصف والكورسات والنتائج وإرسال رابط تغيير كلمة المرور.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$totalStudents',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '$enrolledStudents مسجل بكورس',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final TextEditingController searchController;
  final StudentGrade? gradeFilter;
  final String? courseFilter;
  final List<ManagedCourse> courses;
  final ValueChanged<StudentGrade?> onGradeChanged;
  final ValueChanged<String?> onCourseChanged;
  final VoidCallback onClear;

  const _FiltersCard({
    required this.searchController,
    required this.gradeFilter,
    required this.courseFilter,
    required this.courses,
    required this.onGradeChanged,
    required this.onCourseChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: context.responsiveValue(
                mobile: double.infinity,
                tablet: 300,
                desktop: 330,
              ),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'بحث بالاسم أو البريد',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<StudentGrade?>(
                value: gradeFilter,
                decoration: const InputDecoration(labelText: 'الصف'),
                items: [
                  const DropdownMenuItem<StudentGrade?>(
                    value: null,
                    child: Text('كل الصفوف'),
                  ),
                  ...StudentGrade.values.map(
                    (grade) => DropdownMenuItem<StudentGrade?>(
                      value: grade,
                      child: Text(grade.toArabicDisplay()),
                    ),
                  ),
                ],
                onChanged: onGradeChanged,
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                value: courseFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الكورس'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('كل الكورسات'),
                  ),
                  ...courses.map(
                    (course) => DropdownMenuItem<String?>(
                      value: course.id,
                      child: Text(
                        course.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onCourseChanged,
              ),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('مسح'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final ManagedStudent student;
  final List<ManagedCourse> courses;
  final VoidCallback onEdit;
  final VoidCallback onManageExams;

  const _StudentCard({
    required this.student,
    required this.courses,
    required this.onEdit,
    required this.onManageExams,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        student.displayName.isEmpty ? 'طالب بدون اسم' : student.displayName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: AppColors.primary.withAlpha(25),
              child: Text(
                name.characters.first,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (student.grade != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(18),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            student.grade!.toArabicDisplay(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    student.email,
                    textDirection: TextDirection.ltr,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    courses.isEmpty
                        ? 'غير مسجل في أي كورس'
                        : courses.map((course) => course.title).join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          courses.isEmpty
                              ? AppColors.warning
                              : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (context.isMobile)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'exams') onManageExams();
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('تعديل الحساب والبيانات'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'exams',
                        child: ListTile(
                          leading: Icon(Icons.fact_check_outlined),
                          title: Text('إدارة الدرجات والاختبارات'),
                        ),
                      ),
                    ],
              )
            else ...[
              OutlinedButton.icon(
                onPressed: onManageExams,
                icon: const Icon(Icons.fact_check_outlined, size: 17),
                label: const Text('الدرجات والاختبارات'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('تعديل الطالب'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
