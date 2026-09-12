import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/join_code_repository.dart';

Future<void> showCreateAdminDialog(
  BuildContext context,
  UserEntity currentAdmin, {
  VoidCallback? onAdminCreated,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CreateAdminDialog(
      currentAdmin: currentAdmin,
      onAdminCreated: onAdminCreated,
    ),
  );
}

class CreateAdminDialog extends StatefulWidget {
  final UserEntity currentAdmin;
  final VoidCallback? onAdminCreated;

  const CreateAdminDialog({
    super.key,
    required this.currentAdmin,
    this.onAdminCreated,
  });

  @override
  State<CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<CreateAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.admin;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAdminAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    FirebaseApp? tempApp;
    try {
      // 1. Initialize an isolated secondary Firebase App instance
      // so the currently logged-in Admin is NOT signed out.
      final appName = 'AdminCreator_${DateTime.now().millisecondsSinceEpoch}';
      tempApp = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );

      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final newAdminId = userCredential.user!.uid;

      // 2. Save new admin profile to Firestore
      final roleValue = _selectedRole == UserRole.superAdmin
          ? AppConstants.roleSuperAdmin
          : AppConstants.roleAdmin;

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(newAdminId)
          .set({
        'id': newAdminId,
        'email': email,
        'displayName': name,
        'role': roleValue,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.currentAdmin.id,
      });

      // 3. Generate initial Join Code for the new admin so students can join their class
      String? generatedCode;
      try {
        final joinCodeEntity = await getIt<JoinCodeRepository>()
            .generateOrRegenerateCode(
          adminId: newAdminId,
          adminName: name,
          createdBy: widget.currentAdmin.id,
        );
        generatedCode = joinCodeEntity.code;
      } catch (_) {
        // Join code generation failure is non-fatal for account creation
      }

      if (mounted) {
        Navigator.pop(context); // Close creation dialog
        widget.onAdminCreated?.call();

        // Show success dialog with credentials and join code
        _showSuccessDialog(
          name: name,
          email: email,
          password: password,
          role: _selectedRole,
          joinCode: generatedCode,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _errorMessage = 'البريد الإلكتروني مسجل بالفعل بحساب آخر.';
        } else if (e.code == 'weak-password') {
          _errorMessage = 'كلمة المرور ضعيفة. يجب أن تتكون من 6 أحرف على الأقل.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'صيغة البريد الإلكتروني غير صحيحة.';
        } else {
          _errorMessage = 'حدث خطأ: ${e.message ?? e.code}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'تعذر إنشاء الحساب: $e';
      });
    } finally {
      if (tempApp != null) {
        try {
          await tempApp.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? joinCode,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'تم إنشاء الحساب بنجاح!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تم إنشاء حساب ${role == UserRole.superAdmin ? "مشرف عام" : "معلم / مشرف"} جديد للمنصة بنجاح. يمكنك مشاركة هذه البيانات معه لتسجيل الدخول:',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _credentialTile(label: 'الاسم', value: name),
              const SizedBox(height: 8),
              _credentialTile(label: 'البريد الإلكتروني', value: email, copyable: true),
              const SizedBox(height: 8),
              _credentialTile(label: 'كلمة المرور', value: password, copyable: true),
              if (joinCode != null) ...[
                const SizedBox(height: 8),
                _credentialTile(
                  label: 'كود انضمام الطلاب للمعلم',
                  value: joinCode,
                  copyable: true,
                  isHighlight: true,
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  Widget _credentialTile({
    required String label,
    required String value,
    bool copyable = false,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.primary.withAlpha(15) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlight ? AppColors.primary.withAlpha(80) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isHighlight ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryLight),
              tooltip: 'نسخ',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم نسخ $label'),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = widget.currentAdmin.role.isSuperAdmin;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'إنشاء حساب معلم جديد',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سيتم إنشاء حساب مشرف/معلم مستقل وتوليد كود انضمام خاص به تلقائياً دون تسجيل خروجك من حسابك الحالي.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Name
                AppTextField(
                  controller: _nameController,
                  label: 'الاسم بالكامل *',
                  hintText: 'مثال: أ. محمد أحمد',
                  prefixIcon: Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'يرجى إدخال اسم المعلم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Email
                AppTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني *',
                  hintText: 'teacher@school.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'صيغة البريد الإلكتروني غير صحيحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Password
                AppTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور *',
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
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
                const SizedBox(height: 12),

                // Role Selector (if super admin)
                if (isSuperAdmin) ...[
                  const Text(
                    'نوع صلاحية الحساب:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<UserRole>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('معلم / مشرف (Admin)'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.superAdmin,
                        child: Text('مشرف عام (Super Admin)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedRole = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Error message display
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        AppButton(
          label: 'إنشاء الحساب',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _createAdminAccount,
        ),
      ],
    );
  }
}
