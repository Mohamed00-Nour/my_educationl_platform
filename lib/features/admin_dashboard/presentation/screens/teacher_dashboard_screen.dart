import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../attendance/presentation/screens/mark_attendance_screen.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/cubit/admin_management_cubit.dart';
import '../../../courses/presentation/screens/course_list_screen.dart';
import '../../../evaluations/presentation/screens/evaluations_ledger_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../progress/presentation/screens/student_progress_screen.dart';
import '../../../quizzes/presentation/screens/admin_quiz_management_screen.dart';
import '../../../quizzes/presentation/screens/ai_import_screen.dart';
import '../../../quizzes/presentation/screens/question_bank_screen.dart';
import '../../../reports/presentation/screens/parent_report_screen.dart';
import 'super_admin_management_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final UserEntity user;

  const TeacherDashboardScreen({super.key, required this.user});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _isLoading = true;
  int _coursesCount = 0;
  int _studentsCount = 0;
  int _questionBankCount = 0;
  List<Map<String, String>> _courses = [];
  List<Map<String, String>> _students = [];
  String _selectedCourseId = '';
  String _selectedCourseTitle = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final firestore = FirebaseFirestore.instance;

      final coursesSnap =
          await firestore.collection(FirestoreCollections.courses).get();

      // Tenant-isolated student query: scoped to current Admin, or all if Super Admin
      Query<Map<String, dynamic>> studentsQuery = firestore
          .collection(FirestoreCollections.users)
          .where('role', isEqualTo: AppConstants.roleStudent);

      if (!widget.user.role.isSuperAdmin) {
        studentsQuery = studentsQuery.where(
          'ownerAdminId',
          isEqualTo: widget.user.id,
        );
      }

      final studentsSnap = await studentsQuery.get();
      final qbSnap =
          await firestore.collection(FirestoreCollections.questionBank).get();

      // Tenant-isolated courses: scoped to current Admin, or all if Super Admin
      final filteredCourseDocs =
          coursesSnap.docs.where((d) {
            if (widget.user.role.isSuperAdmin) return true;
            final owner = d.data()['ownerAdminId'] as String?;
            return owner == widget.user.id || owner == null;
          }).toList();

      final coursesList =
          filteredCourseDocs.map((d) {
            final data = d.data();
            return {
              'id': d.id,
              'title':
                  (data['title'] as String?)?.trim().isNotEmpty == true
                      ? (data['title'] as String)
                      : 'كورس بدون عنوان',
            };
          }).toList();

      final studentsList =
          studentsSnap.docs.map((d) {
            final data = d.data();
            final name = (data['displayName'] as String?)?.trim();
            final email = (data['email'] as String?)?.trim();
            final grade = (data['grade'] as String?)?.trim();
            final enrolledCourseIds = List<String>.from(
              data['enrolledCourseIds'] ?? [],
            );
            return {
              'id': d.id,
              'name':
                  (name != null && name.isNotEmpty)
                      ? name
                      : (email != null && email.isNotEmpty ? email : 'طالب'),
              'email': email ?? '',
              'grade': grade ?? '',
              'courses': enrolledCourseIds.join(','),
            };
          }).toList();

      if (mounted) {
        setState(() {
          _coursesCount = filteredCourseDocs.length;
          _studentsCount = studentsSnap.docs.length;
          _questionBankCount = qbSnap.docs.length;
          _courses = coursesList;
          _students = studentsList;
          if (_courses.isNotEmpty) {
            final exists = _courses.any((c) => c['id'] == _selectedCourseId);
            if (!exists || _selectedCourseId.isEmpty) {
              _selectedCourseId = _courses.first['id']!;
              _selectedCourseTitle = _courses.first['title']!;
            }
          } else {
            _selectedCourseId = '';
            _selectedCourseTitle = '';
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pickStudentAndNavigate(
    BuildContext context, {
    required String title,
    required Function(String studentId, String studentName) onPicked,
  }) {
    // Filter students to only those enrolled in the currently selected course.
    final courseStudents =
        _selectedCourseId.isEmpty
            ? _students
            : _students.where((s) {
              final courses = s['courses'] ?? '';
              return courses.split(',').contains(_selectedCourseId);
            }).toList();

    if (courseStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedCourseId.isEmpty
                ? 'لا يوجد طلاب مسجلين حتى الآن. سيظهر الطلاب هنا بمجرد تسجيلهم.'
                : 'لا يوجد طلاب مسجلون في الكورس المحدد حتى الآن.',
          ),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    showAdaptiveModal(
      context: context,
      maxWidth: 540,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(60),
                        ),
                      ),
                      child: Text(
                        '${courseStudents.length} طالب',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedCourseTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'الكورس: $_selectedCourseTitle',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: courseStudents.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final s = courseStudents[idx];
                      final name = s['name'] ?? 'طالب';
                      final email = s['email'] ?? '';
                      final gradeEnum = StudentGrade.fromString(s['grade']);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight.withAlpha(30),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'ط',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (gradeEnum != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  gradeEnum.toArabicDisplay(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle:
                            email.isNotEmpty
                                ? Text(
                                  email,
                                  style: const TextStyle(fontSize: 12),
                                )
                                : null,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          Navigator.pop(ctx);
                          onPicked(s['id']!, name);
                        },
                      );
                    },
                  ),
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
        title: const Text('لوحة تحكم المعلم'),
        actions: [
          if (widget.user.role.isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'لوحة الإدارة العليا (Super Admin)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                            SuperAdminManagementScreen(superAdmin: widget.user),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'التنبيهات والإعلانات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => NotificationsScreen(
                        user: widget.user,
                        courseId:
                            _selectedCourseId.isNotEmpty
                                ? _selectedCourseId
                                : null,
                      ),
                ),
              );
            },
          ),
          /*IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'معاينة واجهة الطالب',
            onPressed: () {
              context.read<AuthBloc>().add(
                const RoleSwitchedForDemo(UserRole.student),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم التبديل لمعاينة واجهة الطالب'),
                  backgroundColor: AppColors.primaryLight,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),*/
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => context.read<AuthBloc>().add(SignOutRequested()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ResponsiveContent(
          maxWidth: 1100,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.screenPadding,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.primaryDark,
                      offset: Offset(0, 4.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withAlpha(30),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.displayName.isNotEmpty
                                ? widget.user.displayName
                                : 'المعلم',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'أكاديمية البرمجة لطلاب الثانوية',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(70),
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'المعلم / الإدارة',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Super Admin Quick Access Hub (if super admin)
              if (widget.user.role.isSuperAdmin) ...[
                Card(
                  color: AppColors.secondary.withAlpha(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: AppColors.secondary,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.secondary,
                      size: 30,
                    ),
                    title: const Text(
                      'لوحة الإدارة العليا (Super Admin)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo',
                      ),
                    ),
                    subtitle: const Text(
                      'إدارة جميع المعلمين، التحكم بأكواد الانضمام، ونقل الطلاب بين المشرفين',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => SuperAdminManagementScreen(
                                superAdmin: widget.user,
                              ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Teacher Join Code Tactile Card
              BlocProvider<AdminManagementCubit>(
                create:
                    (_) =>
                        getIt<AdminManagementCubit>()..loadAdminJoinCode(
                          adminId: widget.user.id,
                          adminName: widget.user.displayName,
                        ),
                child: _TeacherJoinCodeCard(admin: widget.user),
              ),
              const SizedBox(height: 20),

              // Active Course Selector Strip (if courses exist)
              if (_courses.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'الكورس المحدد:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              _selectedCourseId.isNotEmpty
                                  ? _selectedCourseId
                                  : _courses.first['id'],
                          isExpanded: true,
                          items:
                              _courses.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c['id'],
                                  child: Text(
                                    c['title']!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final matched = _courses.firstWhere(
                                (c) => c['id'] == val,
                              );
                              setState(() {
                                _selectedCourseId = val;
                                _selectedCourseTitle = matched['title']!;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Top Metrics Row
              Row(
                children: [
                  _HubMetric(
                    title: 'الكورسات',
                    count: _isLoading ? '...' : '$_coursesCount',
                    icon: Icons.menu_book,
                  ),
                  const SizedBox(width: 12),
                  _HubMetric(
                    title:
                        _selectedCourseId.isNotEmpty ? 'طلاب الكورس' : 'الطلاب',
                    count:
                        _isLoading
                            ? '...'
                            : '${_selectedCourseId.isNotEmpty ? _students.where((s) {
                                  final courses = s['courses'] ?? '';
                                  return courses.split(',').contains(_selectedCourseId);
                                }).length : _studentsCount}',
                    icon: Icons.people,
                  ),
                  const SizedBox(width: 12),
                  _HubMetric(
                    title: 'بنك الأسئلة',
                    count: _isLoading ? '...' : '$_questionBankCount',
                    icon: Icons.inventory_2,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Priority AI Importer Card
              Card(
                color: AppColors.secondary.withAlpha(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(
                    color: AppColors.secondary,
                    width: 1.5,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => AIImportScreen(
                              courseId:
                                  _selectedCourseId.isNotEmpty
                                      ? _selectedCourseId
                                      : null,
                            ),
                      ),
                    ).then((_) => _loadDashboardData());
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'استيراد الأسئلة',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'الصق كود JSON  للمعاينة والتعديل الفوري ونشر الاختبارات بنقرة واحدة.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'الوحدات والعمليات التعليمية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Grid of Management Modules
              GridView.count(
                crossAxisCount:
                    context.responsiveValue(mobile: 2, tablet: 3, desktop: 4),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: context.responsiveValue(
                  mobile: 1.35,
                  tablet: 1.4,
                  desktop: 1.5,
                ),
                children: [
                  _ModuleCard(
                    title: 'المناهج والدروس',
                    subtitle: 'الكورسات، الوحدات والمذكرات',
                    icon: Icons.layers_outlined,
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseListScreen(user: widget.user),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  _ModuleCard(
                    title: 'تسجيل الحضور',
                    subtitle: 'رصد الحضور والغياب اليومي',
                    icon: Icons.checklist_rtl_outlined,
                    color: AppColors.present,
                    onTap: () {
                      if (_selectedCourseId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'يرجى إنشاء أو اختيار كورس أولاً من المناهج والدروس.',
                            ),
                            backgroundColor: AppColors.info,
                          ),
                        );
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MarkAttendanceScreen(
                                courseId: _selectedCourseId,
                              ),
                        ),
                      );
                    },
                  ),
                  _ModuleCard(
                    title: 'بنك الأسئلة',
                    subtitle: 'تصفح وإعادة استخدام الأسئلة',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => QuestionBankScreen(
                                courseId:
                                    _selectedCourseId.isNotEmpty
                                        ? _selectedCourseId
                                        : null,
                              ),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  _ModuleCard(
                    title: 'إدارة الاختبارات والامتحانات',
                    subtitle: 'إدارة الكويزات، الرموز السرية والنتائج',
                    icon: Icons.quiz_outlined,
                    color: AppColors.primaryLight,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => AdminQuizManagementScreen(
                                user: widget.user,
                                courseId:
                                    _selectedCourseId.isNotEmpty
                                        ? _selectedCourseId
                                        : null,
                                courseTitle:
                                    _selectedCourseTitle.isNotEmpty
                                        ? _selectedCourseTitle
                                        : null,
                              ),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  _ModuleCard(
                    title: 'المكافآت والخصومات',
                    subtitle: 'سجل التقييم ونقاط التفاعل',
                    icon: Icons.star_half_outlined,
                    color: AppColors.bonus,
                    onTap: () {
                      _pickStudentAndNavigate(
                        context,
                        title: 'اختر الطالب لتسجيل المكافأة أو الخصم',
                        onPicked: (studentId, studentName) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => EvaluationsLedgerScreen(
                                    courseId: _selectedCourseId,
                                    studentId: studentId,
                                    studentName: studentName,
                                    isAdmin: true,
                                    teacherName:
                                        widget.user.displayName.isNotEmpty
                                            ? widget.user.displayName
                                            : 'المعلم',
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  _ModuleCard(
                    title: 'تقارير أولياء الأمور (PDF)',
                    subtitle: 'تصدير تقرير جاهز للواتساب',
                    icon: Icons.picture_as_pdf_outlined,
                    color: AppColors.minus,
                    onTap: () {
                      _pickStudentAndNavigate(
                        context,
                        title: 'اختر الطالب لإنشاء تقرير ولي الأمر',
                        onPicked: (studentId, studentName) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ParentReportScreen(
                                    courseId: _selectedCourseId,
                                    courseName:
                                        _selectedCourseTitle.isNotEmpty
                                            ? _selectedCourseTitle
                                            : 'أكاديمية البرمجة',
                                    studentId: studentId,
                                    studentName: studentName,
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  _ModuleCard(
                    title: 'مستوى ودرجات الطلاب',
                    subtitle: 'متابعة تفصيلية للدرجات والتقدم',
                    icon: Icons.insights_outlined,
                    color: AppColors.primaryLight,
                    onTap: () {
                      _pickStudentAndNavigate(
                        context,
                        title: 'اختر الطالب لعرض سجله الدراسي وتفاصيل درجاته',
                        onPicked: (studentId, studentName) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => StudentProgressScreen(
                                    courseId: _selectedCourseId,
                                    studentId: studentId,
                                    studentName: studentName,
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _HubMetric extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;

  const _HubMetric({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
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

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherJoinCodeCard extends StatelessWidget {
  final UserEntity admin;

  const _TeacherJoinCodeCard({required this.admin});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdminManagementCubit, AdminManagementState>(
      listener: (context, state) {
        if (state is AdminJoinCodeLoaded &&
            state.actionSuccessMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionSuccessMessage!),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is AdminManagementError) {
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
        if (state is AdminManagementLoading) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final joinCode = state is AdminJoinCodeLoaded ? state.joinCode : null;
        final isOperating = state is AdminJoinCodeLoaded && state.isOperating;
        final isActive = joinCode?.isActive == true;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isActive ? AppColors.primaryDark : AppColors.borderDark,
                offset: const Offset(0, 4.5),
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.vpn_key_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'كود انضمام الطلاب للمعلم',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            'يستخدمه الطلاب أثناء التسجيل للانضمام إلى فصلك',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (joinCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? AppColors.primary.withAlpha(25)
                                : AppColors.error.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? AppColors.primary : AppColors.error,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isActive ? 'مفعّل' : 'معطّل',
                        style: TextStyle(
                          color: isActive ? AppColors.primary : AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Code Display Box
              if (joinCode != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isActive ? AppColors.primary : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              joinCode.code,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color:
                                    isActive
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Copy button
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      tooltip: 'نسخ الكود',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: joinCode.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ كود الانضمام إلى الحافظة'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Controls row
                Row(
                  children: [
                    // Regenerate Code Button
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        icon:
                            isOperating
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          'تجديد الكود',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed:
                            isOperating
                                ? null
                                : () =>
                                    _confirmRegenerate(context, joinCode.code),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Toggle Active / Inactive Switch
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isActive ? 'مفعّل' : 'معطّل',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isActive
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: isActive,
                          activeColor: AppColors.primary,
                          onChanged:
                              isOperating
                                  ? null
                                  : (val) {
                                    context
                                        .read<AdminManagementCubit>()
                                        .toggleCodeStatus(
                                          codeHash: joinCode.codeHash,
                                          isActive: val,
                                        );
                                  },
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('إنشاء كود انضمام للطلاب'),
                  onPressed: () {
                    context.read<AdminManagementCubit>().regenerateJoinCode(
                      adminId: admin.id,
                      adminName: admin.displayName,
                      createdBy: admin.id,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmRegenerate(BuildContext context, String currentCode) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تأكيد تجديد كود المعلم'),
            content: const Text(
              'هل تريد بالتأكيد إنشاء كود انضمام جديد؟\n\n'
              '• سيتم إبطال الكود الحالي فوراً.\n'
              '• لن يتأثر الطلاب المسجلون مسبقاً بهذا الإجراء إطلاقاً.\n'
              '• سيتعين على الطلاب الجدد إدخال الكود الجديد.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<AdminManagementCubit>().regenerateJoinCode(
                    adminId: admin.id,
                    adminName: admin.displayName,
                    createdBy: admin.id,
                  );
                },
                child: const Text('تأكيد وتجديد'),
              ),
            ],
          ),
    );
  }
}
