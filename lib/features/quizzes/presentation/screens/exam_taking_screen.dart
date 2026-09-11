import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../blocs/exam_runner_bloc.dart';
import 'exam_result_screen.dart';

class ExamTakingScreen extends StatelessWidget {
  final String quizId;
  final UserEntity user;
  final String? startCode;

  const ExamTakingScreen({
    super.key,
    required this.quizId,
    required this.user,
    this.startCode,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => ExamRunnerBloc(getIt<QuizRepository>())..add(
            StartExamEvent(
              quizId: quizId,
              studentId: user.id,
              startCode: startCode,
            ),
          ),
      child: const _ExamTakingView(),
    );
  }
}

class _ExamTakingView extends StatelessWidget {
  const _ExamTakingView();

  void _showSubmitConfirmation(
    BuildContext context,
    ExamInProgressState state,
  ) {
    final unanswered = state.questions.length - state.answeredCount;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تسليم الاختبار؟'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لقد قمت بالإجابة على ${state.answeredCount} من أصل ${state.questions.length} سؤالاً.',
                ),
                if (unanswered > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'تنبيه: يوجد $unanswered سؤال لم تتم الإجابة عليه بعد.',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('متابعة الاختبار'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<ExamRunnerBloc>().add(
                    const SubmitExamEvent(isAutoSubmit: false),
                  );
                },
                child: const Text('تأكيد التسليم'),
              ),
            ],
          ),
    );
  }

  void _showQuestionGridSheet(BuildContext context, ExamInProgressState state) {
    showAdaptiveModal(
      context: context,
      maxWidth: 520,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'قائمة الأسئلة والانتقال السريع',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(state.questions.length, (idx) {
                    final q = state.questions[idx];
                    final isAnswered = state.selectedAnswers.containsKey(q.id);
                    final isCurrent = idx == state.currentQuestionIndex;

                    Color bg = AppColors.surfaceVariant;
                    Color text = AppColors.textSecondary;
                    Color border = AppColors.border;

                    if (isCurrent) {
                      bg = AppColors.primary;
                      text = const Color(0xFF131F24);
                      border = AppColors.primaryDark;
                    } else if (isAnswered) {
                      bg = AppColors.successLight;
                      text = AppColors.success;
                      border = AppColors.success;
                    }

                    return InkWell(
                      onTap: () {
                        context.read<ExamRunnerBloc>().add(
                          GoToQuestionEvent(idx),
                        );
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border, width: 2),
                        ),
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamRunnerBloc, ExamRunnerState>(
      listener: (context, state) {
        if (state is ExamSubmittedSuccessState) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ExamResultScreen(
                    attempt: state.attempt,
                    quiz: state.quiz,
                    wasAutoSubmitted: state.wasAutoSubmitted,
                  ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is ExamRunnerLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is ExamRunnerErrorState) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              message: state.message,
              onRetry: () => Navigator.pop(context),
            ),
          );
        }

        if (state is ExamInProgressState) {
          final isTimeLow = state.remainingSeconds <= 300; // Under 5 mins
          final q = state.currentQuestion;
          final selectedOption = state.selectedAnswers[q.id];

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) {
                _showSubmitConfirmation(context, state);
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(state.quiz.title),
                actions: [
                  // Countdown Timer Display
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isTimeLow
                              ? AppColors.errorLight
                              : AppColors.primaryLight.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isTimeLow
                                ? AppColors.error
                                : AppColors.primaryLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color:
                              isTimeLow ? AppColors.error : AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateTimeUtils.formatRemainingTime(
                            state.remainingSeconds,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color:
                                isTimeLow ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.grid_view_rounded),
                    tooltip: 'جميع الأسئلة',
                    onPressed: () => _showQuestionGridSheet(context, state),
                  ),
                ],
              ),
              body: ResponsiveContent(
                maxWidth: 860,
                child: Column(
                children: [
                  // Duolingo Capsule Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 14,
                        child: LinearProgressIndicator(
                          value:
                              (state.currentQuestionIndex + 1) /
                              state.questions.length,
                          backgroundColor: AppColors.surfaceElevated,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Autosave Status Strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: AppColors.surfaceVariant,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_done_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state.isResumedFromDraft
                              ? 'تم استئناف الجلسة من الحفظ التلقائي'
                              : 'يتم حفظ الإجابات تلقائياً',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'السؤال ${state.currentQuestionIndex + 1} من ${state.questions.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Question & Options Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question Card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'السؤال ${state.currentQuestionIndex + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${q.marks} درجات',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    q.questionText,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Options - Duolingo 3D Choice Cards
                          ...List.generate(q.options.length, (optIdx) {
                            final isSelected = selectedOption == optIdx;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? const Color(0xFF162E3B)
                                        : AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppColors.secondary
                                          : AppColors.border,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        isSelected
                                            ? AppColors.secondaryDark
                                            : AppColors.borderDark,
                                    offset: const Offset(0, 3.5),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  context.read<ExamRunnerBloc>().add(
                                    SelectAnswerEvent(
                                      questionId: q.id,
                                      optionIndex: optIdx,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color:
                                              isSelected
                                                  ? AppColors.secondary
                                                  : AppColors.surfaceElevated,
                                        ),
                                        child: Text(
                                          '${optIdx + 1}',
                                          style: TextStyle(
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          q.options[optIdx],
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                            fontFamily: 'Cairo',
                                          ),
                                        ),
                                      ),
                                      Radio<int>(
                                        value: optIdx,
                                        groupValue: selectedOption,
                                        activeColor: AppColors.secondary,
                                        onChanged: (val) {
                                          if (val != null) {
                                            context.read<ExamRunnerBloc>().add(
                                              SelectAnswerEvent(
                                                questionId: q.id,
                                                optionIndex: val,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Navigation Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      border: Border(
                        top: BorderSide(color: AppColors.border, width: 2),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (state.currentQuestionIndex > 0)
                          Expanded(
                            child: AppButton(
                              label: 'السابق',
                              isOutlined: true,
                              icon: Icons.chevron_right,
                              onPressed: () {
                                context.read<ExamRunnerBloc>().add(
                                  GoToQuestionEvent(
                                    state.currentQuestionIndex - 1,
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          const Spacer(),
                        const SizedBox(width: 12),
                        if (state.isLastQuestion)
                          Expanded(
                            child: AppButton(
                              label: 'تسليم الاختبار',
                              icon: Icons.check,
                              backgroundColor: AppColors.success,
                              isLoading: state.isSubmitting,
                              onPressed:
                                  () => _showSubmitConfirmation(context, state),
                            ),
                          )
                        else
                          Expanded(
                            child: AppButton(
                              label: 'السؤال التالي',
                              icon: Icons.chevron_left,
                              onPressed: () {
                                context.read<ExamRunnerBloc>().add(
                                  GoToQuestionEvent(
                                    state.currentQuestionIndex + 1,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
