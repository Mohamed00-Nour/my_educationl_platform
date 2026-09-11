import 'package:flutter/material.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/repositories/quiz_repository.dart';
import 'quiz_config_screen.dart';

class QuestionBankScreen extends StatefulWidget {
  final String? courseId;
  const QuestionBankScreen({super.key, this.courseId});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  List<QuestionEntity> _questions = [];
  final Set<String> _selectedQuestionIds = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterDifficulty = 'all';

  @override
  void initState() {
    super.initState();
    _loadQuestionBank();
  }

  Future<void> _loadQuestionBank() async {
    setState(() => _isLoading = true);
    try {
      final repo = getIt<QuizRepository>();
      final items = await repo.getQuestionBank(courseId: widget.courseId);
      setState(() {
        _questions = items;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<QuestionEntity> get _filteredQuestions {
    return _questions.where((q) {
      final matchesSearch =
          q.questionText.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (q.topic?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);
      final matchesDifficulty =
          _filterDifficulty == 'all' || q.difficulty == _filterDifficulty;
      return matchesSearch && matchesDifficulty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بنك الأسئلة'),
        actions: [
          if (_selectedQuestionIds.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.add_task),
              label: Text('إنشاء اختبار (${_selectedQuestionIds.length})'),
              onPressed: () {
                final chosen =
                    _questions
                        .where((q) => _selectedQuestionIds.contains(q.id))
                        .toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => QuizConfigScreen(
                          initialQuestions: chosen,
                          courseId: widget.courseId ?? '',
                        ),
                  ),
                );
              },
            ),
        ],
      ),
      body: ResponsiveContent(
        maxWidth: 950,
        child: Column(
          children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'البحث في الأسئلة أو الموضوعات...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _filterDifficulty,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('كل المستويات')),
                    DropdownMenuItem(value: 'easy', child: Text('سهل')),
                    DropdownMenuItem(value: 'medium', child: Text('متوسط')),
                    DropdownMenuItem(value: 'hard', child: Text('صعب')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _filterDifficulty = val);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredQuestions.isEmpty
                    ? const EmptyStateView(
                      icon: Icons.inventory_2_outlined,
                      title: 'بنك الأسئلة فارغ',
                      message:
                          'استورد الأسئلة بالذكاء الاصطناعي أو احفظ الأسئلة من الاختبارات لإضافتها هنا.',
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredQuestions.length,
                      itemBuilder: (context, index) {
                        final q = _filteredQuestions[index];
                        final isSelected = _selectedQuestionIds.contains(q.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedQuestionIds.add(q.id);
                                } else {
                                  _selectedQuestionIds.remove(q.id);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                StatusBadge.difficulty(q.difficulty),
                                if (q.topic != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    q.topic!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                q.questionText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
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
