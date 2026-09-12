import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/validate_join_code_usecase.dart';
import '../bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _teacherCodeController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  // ignore: prefer_final_fields
  UserRole _selectedRole = UserRole.student;
  StudentGrade _selectedGrade = StudentGrade.firstSecondary;

  // Course enrollment state
  List<Map<String, String>> _availableCourses = [];
  String? _selectedCourseId;
  bool _isLoadingCourses = false;
  String? _courseLoadError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _teacherCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_isSignUp) {
      // Students must pick a course before registering.
      if (_selectedRole == UserRole.student &&
          (_availableCourses.isNotEmpty && _selectedCourseId == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار الكورس الخاص بك قبل المتابعة.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      context.read<AuthBloc>().add(
        SignUpRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: _displayNameController.text.trim(),
          role: _selectedRole,
          grade: _selectedRole == UserRole.student ? _selectedGrade : null,
          teacherCode:
              _selectedRole == UserRole.student
                  ? _teacherCodeController.text.trim()
                  : null,
          enrolledCourseId: _selectedCourseId,
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        SignInRequested(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        ),
      );
    }
  }

  Future<void> _loadTeacherCourses() async {
    final code = _teacherCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال كود المعلم أولاً.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingCourses = true;
      _courseLoadError = null;
      _availableCourses = [];
      _selectedCourseId = null;
    });

    try {
      // Step 1: Validate teacher code to get the adminId
      final validateUseCase = getIt<ValidateJoinCodeUseCase>();
      final joinCodeEntity = await validateUseCase.call(code);
      final adminId = joinCodeEntity.adminId;


      // Step 2: Fetch that teacher's courses filtered by selected grade
      final authRepo = getIt<AuthRepository>();
      final courses = await authRepo.fetchCoursesForTeacher(
        adminId: adminId,
        grade: _selectedGrade,
      );

      setState(() {
        _availableCourses = courses;
        _isLoadingCourses = false;
        if (courses.isEmpty) {
          _courseLoadError =
              'لا توجد كورسات متاحة لهذا المعلم في مرحلة ${_selectedGrade.toArabicDisplay()} حتى الآن.';
        }
      });
    } catch (e) {
      setState(() {
        _courseLoadError = 'كود المعلم غير صحيح أو منتهي الصلاحية. تحقّق من الكود واتصال الإنترنت.';
        _isLoadingCourses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthErrorState) {
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
          final isLoading = state is AuthLoading;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: AppColors.border, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // App Branding
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.terminal_rounded,
                                  size: 32,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppConstants.appNameArabic,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                  ),
                                  const Text(
                                    AppConstants.appTaglineArabic,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Tab switcher (Sign in vs Register)
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.8,
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _TabButton(
                                    label: 'تسجيل الدخول',
                                    isSelected: !_isSignUp,
                                    onTap:
                                        () => setState(() => _isSignUp = false),
                                  ),
                                ),
                                Expanded(
                                  child: _TabButton(
                                    label: 'إنشاء حساب جديد',
                                    isSelected: _isSignUp,
                                    onTap:
                                        () => setState(() => _isSignUp = true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Sign up specific fields
                          if (_isSignUp) ...[
                            // Full Name
                            AppTextField(
                              controller: _displayNameController,
                              label: 'الاسم بالكامل',
                              hintText: 'مثال: أحمد محمد علي',
                              prefixIcon: Icons.person_outline,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'يرجى إدخال الاسم بالكامل';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Public admin signup is disabled: only existing admins can create new admin accounts.
                            // Registration from this screen is strictly for students.
                            /*
                            const Text(
                              'نوع الحساب',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _RoleCard(
                                    title: 'طالب',
                                    icon: Icons.school_outlined,
                                    isSelected:
                                        _selectedRole == UserRole.student,
                                    onTap:
                                        () => setState(
                                          () =>
                                              _selectedRole = UserRole.student,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _RoleCard(
                                    title: 'معلم / مشرف',
                                    icon: Icons.assignment_ind_outlined,
                                    isSelected: _selectedRole == UserRole.admin,
                                    onTap:
                                        () => setState(
                                          () => _selectedRole = UserRole.admin,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            */

                            // Grade Selection (for students only)
                            if (_selectedRole == UserRole.student) ...[
                              const Text(
                                'المرحلة الدراسية الثانوية',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _RoleCard(
                                      title: 'أولى ثانوي',
                                      icon: Icons.looks_one_outlined,
                                      isSelected:
                                          _selectedGrade ==
                                          StudentGrade.firstSecondary,
                                      onTap: () => setState(() {
                                        _selectedGrade =
                                            StudentGrade.firstSecondary;
                                        // Reset courses when grade changes
                                        _availableCourses = [];
                                        _selectedCourseId = null;
                                        _courseLoadError = null;
                                      }),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _RoleCard(
                                      title: 'تانية ثانوي',
                                      icon: Icons.looks_two_outlined,
                                      isSelected:
                                          _selectedGrade ==
                                          StudentGrade.secondSecondary,
                                      onTap: () => setState(() {
                                        _selectedGrade =
                                            StudentGrade.secondSecondary;
                                        // Reset courses when grade changes
                                        _availableCourses = [];
                                        _selectedCourseId = null;
                                        _courseLoadError = null;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Teacher Code + Load Courses Button
                              AppTextField(
                                controller: _teacherCodeController,
                                label: 'كود المعلم / المشرف (Teacher Code)',
                                hintText: 'أدخل كود المعلم (مثال: 482731)',
                                prefixIcon: Icons.vpn_key_outlined,
                                validator: (v) {
                                  if (_selectedRole == UserRole.student) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'يرجى إدخال كود المعلم الخاص بك';
                                    }
                                    if (v.trim().length < 4) {
                                      return 'كود المعلم غير مكتمل';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),

                              // Load Courses Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: _isLoadingCourses
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.search_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _isLoadingCourses
                                        ? 'جاري تحميل الكورسات...'
                                        : 'جلب كورسات المعلم',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onPressed:
                                      _isLoadingCourses
                                          ? null
                                          : _loadTeacherCourses,
                                ),
                              ),

                              // Error message
                              if (_courseLoadError != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _courseLoadError!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ],

                              // Course picker
                              if (_availableCourses.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                const Text(
                                  'اختر الكورس الخاص بك:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._availableCourses.map(
                                  (course) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _CourseSelectionCard(
                                      title: course['title']!,
                                      isSelected:
                                          _selectedCourseId == course['id'],
                                      onTap: () => setState(
                                        () =>
                                            _selectedCourseId = course['id'],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ],

                          // Email
                          AppTextField(
                            controller: _emailController,
                            label: 'البريد الإلكتروني',
                            hintText: 'name@example.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'يرجى إدخال البريد الإلكتروني';
                              }
                              if (!v.contains('@') || !v.contains('.')) {
                                return 'يرجى إدخال بريد إلكتروني صالح';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Password
                          AppTextField(
                            controller: _passwordController,
                            label: 'كلمة المرور',
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              onPressed:
                                  () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'يرجى إدخال كلمة المرور';
                              }
                              if (v.trim().length < 6) {
                                return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          AppButton(
                            label:
                                _isSignUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                            isLoading: isLoading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected
                  ? Border.all(color: AppColors.border, width: 1.5)
                  : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color:
                  isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppColors.primaryDark : AppColors.borderDark,
              offset: const Offset(0, 3.5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isSelected
                      ? const Color(0xFF131F24)
                      : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color:
                    isSelected
                        ? const Color(0xFF131F24)
                        : AppColors.textSecondary,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseSelectionCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CourseSelectionCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(20)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
