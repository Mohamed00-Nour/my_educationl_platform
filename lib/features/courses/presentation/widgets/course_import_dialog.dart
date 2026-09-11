import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/course_import_schema.dart';
import '../../domain/services/course_json_parser.dart';
import '../bloc/course_bloc.dart';

class CourseImportDialog extends StatefulWidget {
  final UserEntity user;
  final List<String> existingCourseTitles;

  const CourseImportDialog({
    super.key,
    required this.user,
    required this.existingCourseTitles,
  });

  static Future<void> show(
    BuildContext context, {
    required UserEntity user,
    required List<String> existingCourseTitles,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CourseImportDialog(
        user: user,
        existingCourseTitles: existingCourseTitles,
      ),
    );
  }

  @override
  State<CourseImportDialog> createState() => _CourseImportDialogState();
}

class _CourseImportDialogState extends State<CourseImportDialog> {
  String? _pickedFileName;
  int? _pickedFileSize;
  bool _isLoadingFile = false;
  bool _showPasteArea = false;

  final TextEditingController _pasteController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  StudentGrade _selectedGrade = StudentGrade.firstSecondary;

  CourseImportValidationResult? _validationResult;

  @override
  void dispose() {
    _pasteController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoadingFile = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoadingFile = false;
        });
        return;
      }

      final file = result.files.first;
      _pickedFileName = file.name;
      _pickedFileSize = file.size;

      String jsonString = '';
      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      }

      _processJsonString(jsonString);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر قراءة الملف المحدد: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFile = false;
        });
      }
    }
  }

  void _processJsonString(String rawJson) {
    final validation = CourseJsonParser.parseAndValidate(
      rawJson,
      existingCourseTitles: widget.existingCourseTitles,
    );

    setState(() {
      _validationResult = validation;
      if (validation.isValid && validation.data != null) {
        final d = validation.data!;
        _titleController.text = d.title;
        _descController.text = d.description;
        _yearController.text = d.academicYear;
        _selectedGrade = d.targetGrade;
      }
    });
  }

  void _confirmImport() {
    if (_validationResult == null || !_validationResult!.isValid || _validationResult!.data == null) {
      return;
    }

    final originalData = _validationResult!.data!;
    final trimmedTitle = _titleController.text.trim();
    if (trimmedTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد عنوان صالح للكورس.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Build the sanitized data with user modifications
    final finalImportData = originalData.copyWith(
      title: trimmedTitle,
      description: _descController.text.trim(),
      academicYear: _yearController.text.trim(),
      targetGrade: _selectedGrade,
    );

    context.read<CourseBloc>().add(
          ImportCourseFromJsonRequested(
            importData: finalImportData,
            ownerAdminId: widget.user.id, // Strictly enforce current Admin UID
          ),
        );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'استيراد كورس من ملف JSON',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. File Picker Box
              InkWell(
                onTap: _isLoadingFile ? null : _pickFile,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _pickedFileName != null ? AppColors.primary : AppColors.border,
                      width: _pickedFileName != null ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_isLoadingFile)
                        const SizedBox(
                          height: 32,
                          width: 32,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else ...[
                        Icon(
                          _pickedFileName != null
                              ? Icons.check_circle_rounded
                              : Icons.file_upload_outlined,
                          size: 38,
                          color: _pickedFileName != null ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _pickedFileName != null
                              ? _pickedFileName!
                              : 'انقر لاختيار ملف الكورس (.json) من جهازك',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _pickedFileName != null ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _pickedFileSize != null
                              ? '${(_pickedFileSize! / 1024).toStringAsFixed(1)} KB'
                              : 'يدعم الملفات بصيغة JSON المجهزة بهيكل الوحدات والدروس',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Paste JSON toggle
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: Icon(
                      _showPasteArea ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 16,
                    ),
                    label: Text(
                      _showPasteArea ? 'إخفاء منطقة لصق النص' : 'أو لصق نص JSON يدوياً',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _showPasteArea = !_showPasteArea;
                      });
                    },
                  ),
                ],
              ),

              if (_showPasteArea) ...[
                const SizedBox(height: 4),
                TextField(
                  controller: _pasteController,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: '{\n  "course": {\n    "title": "اسم الكورس",\n    "units": [...]\n  }\n}',
                    labelText: 'كود JSON للكورس',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.rule_folder_rounded, size: 16),
                    label: const Text('فحص ومعاينة النص', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      final text = _pasteController.text.trim();
                      if (text.isNotEmpty) {
                        _pickedFileName = 'نص ملصق يدوياً';
                        _pickedFileSize = text.length;
                        _processJsonString(text);
                      }
                    },
                  ),
                ),
              ],

              // 2. Validation Errors Box
              if (_validationResult != null && !_validationResult!.isValid) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withAlpha(90)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'أخطاء في بنية ملف الكورس (لا يمكن الاستيراد):',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._validationResult!.errors.map(
                        (err) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  err,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 3. Validation Warnings Box
              if (_validationResult != null && _validationResult!.warnings.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withAlpha(90)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._validationResult!.warnings.map(
                        (warn) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                warn,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 4. Valid Preview & Editable Settings
              if (_validationResult != null && _validationResult!.isValid) ...[
                const SizedBox(height: 18),
                const Text(
                  'معاينة بيانات الكورس قبل الاستيراد:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),

                // Stats chips
                Row(
                  children: [
                    _buildMetricChip(
                      icon: Icons.layers_outlined,
                      label: '${_validationResult!.totalUnits} وحدات',
                    ),
                    const SizedBox(width: 8),
                    _buildMetricChip(
                      icon: Icons.menu_book_outlined,
                      label: '${_validationResult!.totalLessons} درساً',
                    ),
                    const SizedBox(width: 8),
                    _buildMetricChip(
                      icon: Icons.attachment_rounded,
                      label: '${_validationResult!.totalMaterials} ملحقاً',
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Editable Title
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الكورس *',
                    hintText: 'مثال: مدخل إلى لغة بايثون',
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'الوصف أو الملاحظات',
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _yearController,
                        decoration: const InputDecoration(
                          labelText: 'العام الدراسي',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Target Grade selector
                const Text(
                  'الصف الدراسي المستهدف:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text(StudentGrade.firstSecondary.toArabicDisplay()),
                        selected: _selectedGrade == StudentGrade.firstSecondary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedGrade = StudentGrade.firstSecondary);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(StudentGrade.secondSecondary.toArabicDisplay()),
                        selected: _selectedGrade == StudentGrade.secondSecondary,
                        onSelected: (val) {
                          if (val) setState(() => _selectedGrade = StudentGrade.secondSecondary);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // Expandable structure view
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: Text(
                      'استعراض هيكل الوحدات (${_validationResult!.data?.units.length ?? 0})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _validationResult!.data?.units.length ?? 0,
                          itemBuilder: (ctx, i) {
                            final unit = _validationResult!.data!.units[i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          unit.title,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '${unit.lessons.length} دروس'
                                          '${unit.bookStartPage != null ? " • صـ ${unit.bookStartPage}" : ""}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text('تأكيد واستيراد الكورس'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: (_validationResult != null && _validationResult!.isValid)
              ? _confirmImport
              : null,
        ),
      ],
    );
  }

  Widget _buildMetricChip({required IconData icon, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withAlpha(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
