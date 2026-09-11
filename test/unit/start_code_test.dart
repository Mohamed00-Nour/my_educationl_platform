import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:instructor/core/utils/start_code_utils.dart';
import 'package:instructor/features/quizzes/data/datasources/exam_local_data_source.dart';
import 'package:instructor/features/quizzes/data/models/quiz_model.dart';
import 'package:instructor/features/quizzes/domain/entities/quiz_entity.dart';

void main() {
  group('StartCodeUtils Tests', () {
    test(
      'generateRandom6DigitCode should produce valid 6-digit numeric strings',
      () {
        for (int i = 0; i < 50; i++) {
          final code = StartCodeUtils.generateRandom6DigitCode();
          expect(code.length, equals(6));
          final parsed = int.tryParse(code);
          expect(parsed, isNotNull);
          expect(parsed! >= 100000 && parsed <= 999999, isTrue);
        }
      },
    );

    test('generateSalt produces a unique non-empty hex string', () {
      final salt1 = StartCodeUtils.generateSalt();
      final salt2 = StartCodeUtils.generateSalt();
      expect(salt1.length, equals(32)); // 16 bytes = 32 hex chars
      expect(salt2.length, equals(32));
      expect(salt1, isNot(equals(salt2)));
    });

    test(
      'hashStartCode and verifyStartCode accurately authenticate correct code offline',
      () {
        const code = '654321';
        final salt = StartCodeUtils.generateSalt();
        final hash = StartCodeUtils.hashStartCode(code, salt);

        // Positive verification
        final isValid = StartCodeUtils.verifyStartCode(
          inputCode: '654321',
          expectedHash: hash,
          salt: salt,
        );
        expect(isValid, isTrue);

        // Negative verification (wrong code)
        final isInvalid = StartCodeUtils.verifyStartCode(
          inputCode: '123456',
          expectedHash: hash,
          salt: salt,
        );
        expect(isInvalid, isFalse);

        // Empty input
        expect(
          StartCodeUtils.verifyStartCode(
            inputCode: '',
            expectedHash: hash,
            salt: salt,
          ),
          isFalse,
        );
      },
    );
  });

  group('QuizEntity Start Code Validation Tests', () {
    test('validateStartCode returns true when requireStartCode is false', () {
      const quiz = QuizEntity(
        id: 'quiz_1',
        title: 'Quiz 1',
        description: 'Desc',
        type: QuizType.quiz,
        courseId: 'course_1',
        requireStartCode: false,
      );

      expect(quiz.validateStartCode(''), isTrue);
      expect(quiz.validateStartCode('999999'), isTrue);
    });

    test(
      'validateStartCode correctly validates offline when requireStartCode is true',
      () {
        const plainCode = '482910';
        final salt = StartCodeUtils.generateSalt();
        final hash = StartCodeUtils.hashStartCode(plainCode, salt);

        final quiz = QuizEntity(
          id: 'quiz_2',
          title: 'Exam 1',
          description: 'Desc',
          type: QuizType.fullExam,
          courseId: 'course_1',
          requireStartCode: true,
          startCodeHash: hash,
          startCodeSalt: salt,
        );

        // Valid entry
        expect(quiz.validateStartCode('482910'), isTrue);
        // Valid entry with whitespace
        expect(quiz.validateStartCode(' 482910 '), isTrue);
        // Invalid entry
        expect(quiz.validateStartCode('000000'), isFalse);
        // Empty entry
        expect(quiz.validateStartCode(''), isFalse);
        expect(quiz.validateStartCode('   '), isFalse);
      },
    );

    test(
      'validateStartCode validates plain startCode when hash is missing',
      () {
        const quiz = QuizEntity(
          id: 'quiz_plain',
          title: 'Plain Code Quiz',
          description: 'Desc',
          type: QuizType.quiz,
          courseId: 'c1',
          requireStartCode: true,
          startCode: '556677',
        );

        expect(quiz.validateStartCode('556677'), isTrue);
        expect(quiz.validateStartCode(' 556677 '), isTrue);
        expect(quiz.validateStartCode('112233'), isFalse);
        expect(quiz.validateStartCode(''), isFalse);
      },
    );
  });

  group('QuizModel Start Code Serialization Tests', () {
    test('QuizModel preserves start code fields in toMap and fromEntity', () {
      final salt = StartCodeUtils.generateSalt();
      final hash = StartCodeUtils.hashStartCode('123456', salt);

      const entity = QuizEntity(
        id: 'quiz_code_1',
        title: 'Quiz with Code',
        description: 'Test Quiz',
        type: QuizType.quiz,
        courseId: 'c1',
        requireStartCode: true,
        startCode: '123456',
        startCodeHash: 'hash123',
        startCodeSalt: 'salt123',
      );

      final model = QuizModel(
        id: entity.id,
        title: entity.title,
        description: entity.description,
        type: entity.type,
        courseId: entity.courseId,
        requireStartCode: entity.requireStartCode,
        startCode: entity.startCode,
        startCodeHash: hash,
        startCodeSalt: salt,
      );

      expect(model.requireStartCode, isTrue);
      expect(model.startCode, equals('123456'));
      expect(model.startCodeHash, equals(hash));
      expect(model.startCodeSalt, equals(salt));

      final map = model.toMap();
      expect(map['requireStartCode'], isTrue);
      expect(map['startCode'], equals('123456'));
      expect(map['startCodeHash'], equals(hash));
      expect(map['startCodeSalt'], equals(salt));

      final fromEnt = QuizModel.fromEntity(entity);
      expect(fromEnt.requireStartCode, isTrue);
      expect(fromEnt.startCode, equals('123456'));
      expect(fromEnt.startCodeHash, equals('hash123'));
      expect(fromEnt.startCodeSalt, equals('salt123'));
    });

    test('QuizModel.fromMap automatically generates hash and salt if missing', () {
      final data = {
        'title': 'Exam with plain start code only',
        'type': 'exam',
        'courseId': 'c2',
        'startCode': '789123',
      };

      final model = QuizModel.fromMap(data, id: 'quiz_auto_hash');
      expect(model.requireStartCode, isTrue);
      expect(model.startCode, equals('789123'));
      expect(model.startCodeHash, isNotNull);
      expect(model.startCodeSalt, isNotNull);
      expect(model.startCodeHash!.isNotEmpty, isTrue);
      expect(model.startCodeSalt!.isNotEmpty, isTrue);

      // Offline validation with the auto-generated hash succeeds
      expect(model.validateStartCode('789123'), isTrue);
      expect(model.validateStartCode('999999'), isFalse);
    });
  });

  group('Offline Caching of Start Code Tests', () {
    test(
      'ExamLocalDataSource caches quiz with start code and can validate offline',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final localDataSource = ExamLocalDataSourceImpl(prefs);

        final rawModel = QuizModel.fromMap({
          'title': 'Offline Exam',
          'type': 'quiz',
          'courseId': 'c3',
          'startCode': '654321',
        }, id: 'offline_quiz_101');

        // Cache the quiz locally for offline use
        await localDataSource.cacheQuiz(rawModel);

        // Verify available offline
        final isAvailable = await localDataSource.isQuizAvailableOffline('offline_quiz_101');
        expect(isAvailable, isTrue);

        // Retrieve the cached quiz
        final cached = await localDataSource.getCachedQuiz('offline_quiz_101');
        expect(cached, isNotNull);
        expect(cached!.requireStartCode, isTrue);
        expect(cached.startCode, equals('654321'));
        expect(cached.startCodeHash, isNotNull);
        expect(cached.startCodeSalt, isNotNull);

        // Offline validation against the retrieved cached quiz
        expect(cached.validateStartCode('654321'), isTrue);
        expect(cached.validateStartCode('111111'), isFalse);
      },
    );
  });
}
