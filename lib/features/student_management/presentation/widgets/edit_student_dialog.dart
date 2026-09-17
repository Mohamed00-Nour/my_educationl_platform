import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/student_management_repository.dart';

class EditStudentDialog extends StatefulWidget {
  final ManagedStudent student;
  final List<ManagedCourse> courses;
  final StudentManagementRepository repository;

  const EditStudentDialog({
    super.key,
    required this.student,
    required this.courses,
    required this.repository,
  });

  @override
  State<EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late StudentGrade _grade;
  late Set<String> _courseIds;
  late int _unavailableCourseCount;
  bool _saving = false;
  bool _sendingReset = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.displayName);
    _grade = widget.student.grade ?? StudentGrade.firstSecondary;
    final availableCourseIds =
        widget.courses.map((course) => course.id).toSet();
    _courseIds =
        widget.student.enrolledCourseIds
            .where(availableCourseIds.contains)
            .toSet();
    _unavailableCourseCount =
        widget.student.enrolledCourseIds.length - _courseIds.length;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.repository.updateStudent(
        student: widget.student,
        displayName: _nameController.text,
        grade: _grade,
        enrolledCourseIds: _courseIds.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } on StudentManagementException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _friendlyMessage(error);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر حفظ بيانات الطالب. حاول مرة أخرى. ($error)';
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    setState(() {
      _sendingReset = true;
      _error = null;
    });
    try {
      await widget.repository.sendPasswordReset(widget.student);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال رابط تغيير كلمة المرور إلى ${widget.student.email}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() => _sendingReset = false);
    } on StudentManagementException catch (error) {
      if (mounted) {
        setState(() {
          _sendingReset = false;
          _error = _friendlyMessage(error);
        });
      }
    }
  }

  String _friendlyMessage(StudentManagementException error) {
    switch (error.code) {
      case 'already-exists':
        return 'البريد الإلكتروني مستخدم في حساب آخر.';
      case 'permission-denied':
        return 'ليس لديك صلاحية تعديل هذا الطالب.';
      case 'not-found':
        return 'تعذر العثور على الطالب أو أحد الكورسات.';
      case 'invalid-argument':
        return error.message;
      case 'unavailable':
        return 'خدمة إدارة الحسابات غير متاحة حالياً. حاول لاحقاً.';
      default:
        return error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(child: Text('تعديل بيانات الطالب')),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_saving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم الطالب',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 2) return 'اكتب اسم الطالب';
                    if (text.length > 80) return 'الاسم طويل جداً';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'بريد تسجيل الدخول',
                    prefixIcon: Icon(Icons.alternate_email),
                    helperText:
                        'تغيير بريد حساب طالب آخر يحتاج خادماً مدفوعاً؛ البريد للعرض فقط.',
                  ),
                  child: Text(
                    widget.student.email,
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      _saving || _sendingReset ? null : _sendPasswordReset,
                  icon:
                      _sendingReset
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.mark_email_read_outlined),
                  label: Text(
                    _sendingReset
                        ? 'جارٍ إرسال الرابط...'
                        : 'إرسال رابط تغيير كلمة المرور للطالب',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<StudentGrade>(
                  value: _grade,
                  decoration: const InputDecoration(
                    labelText: 'الصف الدراسي',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  items:
                      StudentGrade.values
                          .map(
                            (grade) => DropdownMenuItem(
                              value: grade,
                              child: Text(grade.toArabicDisplay()),
                            ),
                          )
                          .toList(),
                  onChanged:
                      _saving
                          ? null
                          : (grade) {
                            if (grade != null) setState(() => _grade = grade);
                          },
                ),
                const SizedBox(height: 18),
                const Text(
                  'الكورسات المسجل بها الطالب',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (_unavailableCourseCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.warning.withAlpha(80),
                      ),
                    ),
                    child: Text(
                      'يوجد $_unavailableCourseCount كورس غير تابع لهذا المعلم. '
                      'سيتم فك تسجيل الطالب منه عند الحفظ.',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (widget.courses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'لا توجد كورسات متاحة لهذا المعلم.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  ...widget.courses.map(
                    (course) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _courseIds.contains(course.id),
                      title: Text(course.title),
                      subtitle:
                          course.targetGrade == null
                              ? null
                              : Text(course.targetGrade!.toArabicDisplay()),
                      onChanged:
                          _saving
                              ? null
                              : (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _courseIds.add(course.id);
                                  } else {
                                    _courseIds.remove(course.id);
                                  }
                                });
                              },
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withAlpha(80)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon:
              _saving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
        ),
      ],
    );
  }
}
