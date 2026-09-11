import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/evaluation_adjustment.dart';

class AddAdjustmentDialog extends StatefulWidget {
  final String courseId;
  final String studentId;
  final String studentName;
  final String teacherName;
  final ValueChanged<EvaluationAdjustment> onSaved;

  const AddAdjustmentDialog({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.teacherName,
    required this.onSaved,
  });

  @override
  State<AddAdjustmentDialog> createState() => _AddAdjustmentDialogState();
}

class _AddAdjustmentDialogState extends State<AddAdjustmentDialog> {
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  final _pointsController = TextEditingController(text: '3');
  AdjustmentType _type = AdjustmentType.bonus;

  final List<String> _bonusPresets = [
    'مشاركة وتفاعل ممتاز في الحصة',
    'إجابة نموذجية في التحدي البرمجي',
    'مساعدة الزملاء في فهم الكود',
    'حل واجب إضافي مميز',
  ];

  final List<String> _minusPresets = [
    'عدم تسليم الواجب المطلوب',
    'تشتت وعدم تركيز في الحصة',
    'تأخر في تسليم المشروع البرمجي',
    'عدم إكمال التطبيق العملي',
  ];

  @override
  Widget build(BuildContext context) {
    final presets =
        _type == AdjustmentType.bonus ? _bonusPresets : _minusPresets;

    return AlertDialog(
      title: Text('إضافة تقييم للطالب: ${widget.studentName}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bonus vs Minus Selector
              Row(
                children: [
                  Expanded(
                    child: _TypeSelectCard(
                      title: 'مكافأة (+)',
                      color: AppColors.bonus,
                      isSelected: _type == AdjustmentType.bonus,
                      onTap: () => setState(() => _type = AdjustmentType.bonus),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeSelectCard(
                      title: 'خصم (-)',
                      color: AppColors.minus,
                      isSelected: _type == AdjustmentType.minus,
                      onTap: () => setState(() => _type = AdjustmentType.minus),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Points Input
              AppTextField(
                controller: _pointsController,
                label: 'النقاط (${_type == AdjustmentType.bonus ? '+' : '-'})',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              // Quick Preset Chips
              const Text(
                'عبارات جاهزة:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    presets.map((p) {
                      return ActionChip(
                        label: Text(p, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.surfaceVariant,
                        onPressed:
                            () => setState(() => _reasonController.text = p),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 14),

              // Reason Input
              AppTextField(
                controller: _reasonController,
                label: 'السبب أو الملاحظة',
                hintText: 'مثال: تفاعل ممتاز وحل التمرين العملي',
              ),
              const SizedBox(height: 14),

              // Teacher Notes Input
              AppTextField(
                controller: _notesController,
                label: 'ملاحظة خاصة من المعلم (اختياري)',
                hintText: 'ملاحظات لولي الأمر أو للسجل الداخلي...',
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _type == AdjustmentType.bonus
                    ? AppColors.bonus
                    : AppColors.minus,
          ),
          onPressed: () {
            final reason = _reasonController.text.trim();
            final pts = int.tryParse(_pointsController.text.trim()) ?? 1;
            if (reason.isNotEmpty) {
              final adjustment = EvaluationAdjustment(
                id: '',
                studentId: widget.studentId,
                studentName: widget.studentName,
                courseId: widget.courseId,
                points: _type == AdjustmentType.bonus ? pts.abs() : -pts.abs(),
                type: _type,
                reason: reason,
                date: DateTime.now(),
                addedBy: widget.teacherName,
                teacherNotes:
                    _notesController.text.trim().isNotEmpty
                        ? _notesController.text.trim()
                        : null,
              );
              widget.onSaved(adjustment);
              Navigator.pop(context);
            }
          },
          child: const Text('حفظ التقييم'),
        ),
      ],
    );
  }
}

class _TypeSelectCard extends StatelessWidget {
  final String title;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeSelectCard({
    required this.title,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isSelected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
