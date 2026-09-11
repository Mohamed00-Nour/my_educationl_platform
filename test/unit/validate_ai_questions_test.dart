import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/features/quizzes/domain/usecases/validate_ai_questions_usecase.dart';

void main() {
  late ValidateAIQuestionsUseCase useCase;

  setUp(() {
    useCase = ValidateAIQuestionsUseCase();
  });

  group('ValidateAIQuestionsUseCase Tests', () {
    test('should parse valid MCQ and True/False questions successfully', () {
      const sampleJson = '''[
        {
          "type": "mcq",
          "question": "What is a variable?",
          "options": ["A memory storage location", "A monitor", "A mouse", "A cable"],
          "correctAnswer": 0,
          "explanation": "Variables store values in memory.",
          "difficulty": "easy"
        },
        {
          "type": "trueFalse",
          "question": "Python is an interpreted language.",
          "options": ["True", "False"],
          "correctAnswer": 0,
          "explanation": "Python code is executed line by line by the interpreter.",
          "difficulty": "easy"
        }
      ]''';

      final summary = useCase.execute(sampleJson);

      expect(summary.totalDetected, 2);
      expect(summary.validCount, 2);
      expect(summary.needsReviewCount, 0);
      expect(summary.canPublish, true);
    });

    test('should detect markdown code fences and clean them automatically', () {
      const fencedJson = '''```json
      [
        {
          "type": "mcq",
          "question": "What is a function?",
          "options": ["Reusable block of code", "A computer chip"],
          "correctAnswer": 0,
          "difficulty": "easy"
        }
      ]
      ```''';

      final summary = useCase.execute(fencedJson);

      expect(summary.totalDetected, 1);
      expect(summary.validCount, 1);
      expect(summary.items.first.question.questionText, 'What is a function?');
    });

    test('should flag out-of-bounds correct answer index', () {
      const faultyJson = '''[
        {
          "type": "mcq",
          "question": "Faulty Question?",
          "options": ["Option A", "Option B"],
          "correctAnswer": 5,
          "difficulty": "medium"
        }
      ]''';

      final summary = useCase.execute(faultyJson);

      expect(summary.totalDetected, 1);
      expect(summary.validCount, 0);
      expect(summary.needsReviewCount, 1);
      expect(summary.items.first.isValid, false);
      expect(
        summary.items.first.errors.any((e) => e.contains('out of bounds')),
        true,
      );
    });

    test('should flag duplicate questions', () {
      const duplicateJson = '''[
        {
          "type": "mcq",
          "question": "What is a loop?",
          "options": ["Repetition", "Storage"],
          "correctAnswer": 0
        },
        {
          "type": "mcq",
          "question": "What is a loop?",
          "options": ["A circle", "A line"],
          "correctAnswer": 0
        }
      ]''';

      final summary = useCase.execute(duplicateJson);

      expect(summary.totalDetected, 2);
      expect(summary.validCount, 1);
      expect(summary.needsReviewCount, 1);
      expect(summary.items[1].isDuplicate, true);
    });
  });
}
