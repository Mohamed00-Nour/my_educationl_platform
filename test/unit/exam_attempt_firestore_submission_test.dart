import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/core/constants/app_constants.dart';
import 'package:instructor/features/quizzes/data/datasources/quiz_remote_data_source.dart';
import 'package:instructor/features/quizzes/data/models/exam_attempt_model.dart';
import 'package:mocktail/mocktail.dart';

class _Firestore extends Mock implements FirebaseFirestore {}

class _Collection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _Document extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _Snapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(const GetOptions(source: Source.server));
  });

  late _Firestore firestore;
  late _Collection collection;
  late _Document document;
  late QuizRemoteDataSourceImpl dataSource;
  late ExamAttemptModel attempt;

  setUp(() {
    firestore = _Firestore();
    collection = _Collection();
    document = _Document();
    dataSource = QuizRemoteDataSourceImpl(firestore: firestore);
    final now = DateTime.now();
    attempt = ExamAttemptModel(
      id: 'attempt-id',
      studentId: 'student-id',
      examId: 'quiz-id',
      courseId: 'course-id',
      startedAt: now.subtract(const Duration(minutes: 1)),
      submittedAt: now,
      durationSecondsUsed: 60,
      answers: const {},
      correctCount: 1,
      incorrectCount: 0,
      score: 1,
      percentage: 100,
      isPassed: true,
    );
    when(
      () => firestore.collection(FirestoreCollections.examAttempts),
    ).thenReturn(collection);
    when(() => collection.doc('attempt-id')).thenReturn(document);
  });

  test('creates a new student attempt without first reading it', () async {
    when(() => document.set(any())).thenAnswer((_) async {});

    final saved = await dataSource.submitExamAttempt(attempt);

    expect(saved.id, 'attempt-id');
    verify(() => document.set(any())).called(1);
    verifyNever(() => document.get(any()));
  });

  test('accepts a retry only when the saved document is the same attempt', () async {
    final snapshot = _Snapshot();
    when(() => document.set(any())).thenThrow(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    when(() => document.get(any())).thenAnswer((_) async => snapshot);
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.id).thenReturn('attempt-id');
    when(() => snapshot.data()).thenReturn(attempt.toMap());

    final saved = await dataSource.submitExamAttempt(attempt);

    expect(saved.id, 'attempt-id');
    expect(saved.studentId, 'student-id');
    verify(() => document.get(any())).called(1);
  });
}
