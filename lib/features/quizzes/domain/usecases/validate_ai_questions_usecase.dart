import 'package:uuid/uuid.dart';
import '../../../../core/utils/json_sanitizer.dart';
import '../entities/ai_import_item.dart';
import '../entities/question_entity.dart';

class ValidateAIQuestionsUseCase {
  final Uuid _uuid = const Uuid();

  AIImportSummary execute(String rawJson) {
    if (rawJson.trim().isEmpty) {
      return const AIImportSummary(
        totalDetected: 0,
        validCount: 0,
        needsReviewCount: 0,
        items: [],
      );
    }

    dynamic decoded;
    try {
      decoded = JsonSanitizer.sanitizeAndDecode(rawJson);
    } catch (e) {
      // Syntax parsing error
      return AIImportSummary(
        totalDetected: 0,
        validCount: 0,
        needsReviewCount: 1,
        items: [
          AIImportItem(
            index: 1,
            question: QuestionEntity(
              id: _uuid.v4(),
              type: 'mcq',
              questionText: 'Malformed JSON input',
              options: const [],
              correctAnswerIndex: -1,
            ),
            isValid: false,
            errors: ['Invalid JSON syntax: ${e.toString().split('\n').first}'],
          ),
        ],
      );
    }

    List<dynamic> rawList = [];
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map &&
        decoded.containsKey('questions') &&
        decoded['questions'] is List) {
      rawList = decoded['questions'] as List;
    } else if (decoded is Map) {
      rawList = [decoded];
    }

    final List<AIImportItem> items = [];
    final Set<String> seenQuestionTexts = {};

    for (int i = 0; i < rawList.length; i++) {
      final raw = rawList[i];
      final List<String> errors = [];

      if (raw is! Map) {
        items.add(
          AIImportItem(
            index: i + 1,
            question: QuestionEntity(
              id: _uuid.v4(),
              type: 'mcq',
              questionText: 'Item is not a valid JSON object',
              options: const [],
              correctAnswerIndex: -1,
            ),
            isValid: false,
            errors: const ['Question entry must be a JSON object {...}'],
          ),
        );
        continue;
      }

      final map = Map<String, dynamic>.from(raw);
      final questionText =
          (map['question'] ?? map['questionText'] ?? map['text'] ?? '')
              .toString()
              .trim();
      final type = (map['type'] ?? 'mcq').toString().trim().toLowerCase();
      final explanation =
          (map['explanation'] ?? map['rationale'] ?? '').toString().trim();
      final difficulty =
          (map['difficulty'] ?? 'medium').toString().trim().toLowerCase();
      final marks = (map['marks'] is num) ? (map['marks'] as num).toInt() : 1;
      final topic = map['topic']?.toString().trim();

      // Check Question Text
      if (questionText.isEmpty) {
        errors.add('Missing question text');
      }

      // Check Duplicates
      final normalizedText = questionText.toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      bool isDuplicate = false;
      if (questionText.isNotEmpty &&
          seenQuestionTexts.contains(normalizedText)) {
        isDuplicate = true;
        errors.add('Duplicate question detected');
      } else if (questionText.isNotEmpty) {
        seenQuestionTexts.add(normalizedText);
      }

      // Parse Options
      List<String> options = [];
      if (map['options'] is List) {
        options =
            (map['options'] as List).map((e) => e.toString().trim()).toList();
      } else if (type == 'truefalse' || type == 'tf') {
        options = ['True', 'False'];
      }

      if (type == 'mcq' && options.length < 2) {
        errors.add('Multiple choice must have at least 2 options');
      }

      // Parse Correct Answer Index
      int correctIndex = -1;
      final rawCorrect =
          map['correctAnswer'] ?? map['correctAnswerIndex'] ?? map['answer'];

      if (rawCorrect == null) {
        errors.add('Missing correct answer');
      } else if (rawCorrect is num) {
        correctIndex = rawCorrect.toInt();
      } else if (rawCorrect is String) {
        final parsedNum = int.tryParse(rawCorrect);
        if (parsedNum != null) {
          correctIndex = parsedNum;
        } else {
          // String match against options
          final trimmedAnswer = rawCorrect.trim();
          final found = options.indexWhere(
            (opt) => opt.toLowerCase() == trimmedAnswer.toLowerCase(),
          );
          if (found != -1) {
            correctIndex = found;
          } else if (type == 'truefalse' || type == 'tf') {
            if (trimmedAnswer.toLowerCase() == 'true') correctIndex = 0;
            if (trimmedAnswer.toLowerCase() == 'false') correctIndex = 1;
          }
        }
      } else if (rawCorrect is bool) {
        correctIndex = rawCorrect ? 0 : 1;
        if (options.isEmpty) {
          options = ['True', 'False'];
        }
      }

      if (correctIndex < 0 ||
          (options.isNotEmpty && correctIndex >= options.length)) {
        errors.add(
          'Correct answer index ($correctIndex) is out of bounds (options: ${options.length})',
        );
      }

      final questionEntity = QuestionEntity(
        id: map['id']?.toString() ?? _uuid.v4(),
        type: (type == 'truefalse' || type == 'tf') ? 'trueFalse' : 'mcq',
        questionText:
            questionText.isNotEmpty ? questionText : 'Untitled Question',
        options: options,
        correctAnswerIndex: correctIndex,
        explanation: explanation,
        marks: marks,
        difficulty:
            (['easy', 'medium', 'hard'].contains(difficulty))
                ? difficulty
                : 'medium',
        topic: topic,
      );

      final isValid = errors.isEmpty;
      items.add(
        AIImportItem(
          index: i + 1,
          question: questionEntity,
          isValid: isValid,
          errors: errors,
          isDuplicate: isDuplicate,
        ),
      );
    }

    final validCount = items.where((it) => it.isValid).length;
    final needsReviewCount = items.length - validCount;

    return AIImportSummary(
      totalDetected: items.length,
      validCount: validCount,
      needsReviewCount: needsReviewCount,
      items: items,
    );
  }
}
