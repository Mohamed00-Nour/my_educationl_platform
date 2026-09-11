import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/local_attempt_entity.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../models/local_attempt_model.dart';
import '../models/quiz_model.dart';

abstract class ExamLocalDataSource {
  // Legacy Draft methods
  Future<void> saveActiveExamDraft({
    required String quizId,
    required String studentId,
    required Map<String, int> answers,
    required int remainingSeconds,
  });

  Future<LocalExamDraft?> loadActiveExamDraft({
    required String quizId,
    required String studentId,
  });

  Future<void> clearActiveExamDraft({
    required String quizId,
    required String studentId,
  });

  // Offline Quiz Caching
  Future<void> cacheQuiz(QuizModel quiz);
  Future<QuizModel?> getCachedQuiz(String quizId);
  Future<List<QuizModel>> getAllCachedQuizzes();
  Future<bool> isQuizAvailableOffline(String quizId);
  Future<void> removeCachedQuiz(String quizId);

  // Active In-Progress Attempt
  Future<void> saveActiveAttempt(LocalAttemptModel attempt);
  Future<LocalAttemptModel?> loadActiveAttempt(String quizId, String studentId);
  Future<void> clearActiveAttempt(String quizId, String studentId);

  // Completed & Pending Sync Attempts
  Future<void> saveCompletedAttempt(LocalAttemptModel attempt);
  Future<List<LocalAttemptModel>> getPendingAttempts();
  Future<List<LocalAttemptModel>> getCompletedAttempts(String studentId);
  Future<void> updateAttemptStatus(
    String attemptId,
    AttemptSyncStatus status, {
    String? error,
  });
}

class ExamLocalDataSourceImpl implements ExamLocalDataSource {
  final SharedPreferences _prefs;

  static const String _keyCachedQuizIds = 'cached_offline_quiz_ids';
  static const String _keyPendingAttemptIds = 'pending_sync_attempt_ids';

  ExamLocalDataSourceImpl(this._prefs);

  String _getDraftKey(String quizId, String studentId) =>
      '${AppConstants.keyActiveAttemptPrefix}${quizId}_$studentId';

  String _getActiveAttemptKey(String quizId, String studentId) =>
      'active_attempt_${quizId}_$studentId';

  String _getCompletedAttemptKey(String attemptId) =>
      'completed_attempt_$attemptId';

  String _getCachedQuizKey(String quizId) => 'offline_quiz_$quizId';

  String _getStudentAttemptsKey(String studentId) =>
      'student_attempts_$studentId';

  // ==========================================
  // LEGACY DRAFT METHODS
  // ==========================================

  @override
  Future<void> saveActiveExamDraft({
    required String quizId,
    required String studentId,
    required Map<String, int> answers,
    required int remainingSeconds,
  }) async {
    final key = _getDraftKey(quizId, studentId);
    final payload = jsonEncode({
      'answers': answers,
      'remainingSeconds': remainingSeconds,
      'savedAt': DateTime.now().toIso8601String(),
    });
    await _prefs.setString(key, payload);
  }

  @override
  Future<LocalExamDraft?> loadActiveExamDraft({
    required String quizId,
    required String studentId,
  }) async {
    final key = _getDraftKey(quizId, studentId);
    final raw = _prefs.getString(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawAnswers = decoded['answers'] as Map<String, dynamic>? ?? {};
      final Map<String, int> answers = {};
      rawAnswers.forEach((k, v) {
        if (v is num) answers[k] = v.toInt();
      });

      return LocalExamDraft(
        answers: answers,
        remainingSeconds: (decoded['remainingSeconds'] as num?)?.toInt() ?? 0,
        savedAt:
            DateTime.tryParse(decoded['savedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearActiveExamDraft({
    required String quizId,
    required String studentId,
  }) async {
    final key = _getDraftKey(quizId, studentId);
    await _prefs.remove(key);
  }

  // ==========================================
  // OFFLINE QUIZ CACHING
  // ==========================================

  @override
  Future<void> cacheQuiz(QuizModel quiz) async {
    final key = _getCachedQuizKey(quiz.id);
    await _prefs.setString(key, jsonEncode(quiz.toJson()));

    // Store dedicated offline start code validation credentials
    final prefix = 'offline_quiz_start_code_';
    await _prefs.setBool('${prefix}required_${quiz.id}', quiz.requireStartCode);
    if (quiz.startCode != null && quiz.startCode!.isNotEmpty) {
      await _prefs.setString('${prefix}plain_${quiz.id}', quiz.startCode!);
    }
    if (quiz.startCodeHash != null && quiz.startCodeHash!.isNotEmpty) {
      await _prefs.setString('${prefix}hash_${quiz.id}', quiz.startCodeHash!);
    }
    if (quiz.startCodeSalt != null && quiz.startCodeSalt!.isNotEmpty) {
      await _prefs.setString('${prefix}salt_${quiz.id}', quiz.startCodeSalt!);
    }

    final ids = _prefs.getStringList(_keyCachedQuizIds) ?? [];
    if (!ids.contains(quiz.id)) {
      ids.add(quiz.id);
      await _prefs.setStringList(_keyCachedQuizIds, ids);
    }
  }

  @override
  Future<QuizModel?> getCachedQuiz(String quizId) async {
    final key = _getCachedQuizKey(quizId);
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;

      // Ensure dedicated start code credentials are reconstructed if missing
      final prefix = 'offline_quiz_start_code_';
      if ((json['requireStartCode'] == null || json['requireStartCode'] == false) &&
          _prefs.getBool('${prefix}required_$quizId') == true) {
        json['requireStartCode'] = true;
      }
      if ((json['startCode'] == null || json['startCode'].toString().isEmpty) &&
          _prefs.containsKey('${prefix}plain_$quizId')) {
        json['startCode'] = _prefs.getString('${prefix}plain_$quizId');
      }
      if ((json['startCodeHash'] == null || json['startCodeHash'].toString().isEmpty) &&
          _prefs.containsKey('${prefix}hash_$quizId')) {
        json['startCodeHash'] = _prefs.getString('${prefix}hash_$quizId');
      }
      if ((json['startCodeSalt'] == null || json['startCodeSalt'].toString().isEmpty) &&
          _prefs.containsKey('${prefix}salt_$quizId')) {
        json['startCodeSalt'] = _prefs.getString('${prefix}salt_$quizId');
      }

      return QuizModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<QuizModel>> getAllCachedQuizzes() async {
    final ids = _prefs.getStringList(_keyCachedQuizIds) ?? [];
    final List<QuizModel> quizzes = [];
    for (final id in ids) {
      final q = await getCachedQuiz(id);
      if (q != null) quizzes.add(q);
    }
    return quizzes;
  }

  @override
  Future<bool> isQuizAvailableOffline(String quizId) async {
    final key = _getCachedQuizKey(quizId);
    return _prefs.containsKey(key);
  }

  @override
  Future<void> removeCachedQuiz(String quizId) async {
    final key = _getCachedQuizKey(quizId);
    await _prefs.remove(key);

    // Remove dedicated offline start code keys
    final prefix = 'offline_quiz_start_code_';
    await _prefs.remove('${prefix}required_$quizId');
    await _prefs.remove('${prefix}plain_$quizId');
    await _prefs.remove('${prefix}hash_$quizId');
    await _prefs.remove('${prefix}salt_$quizId');

    final ids = _prefs.getStringList(_keyCachedQuizIds) ?? [];
    ids.remove(quizId);
    await _prefs.setStringList(_keyCachedQuizIds, ids);
  }

  // ==========================================
  // ACTIVE ATTEMPT (PERSISTENCE & RECOVERY)
  // ==========================================

  @override
  Future<void> saveActiveAttempt(LocalAttemptModel attempt) async {
    final key = _getActiveAttemptKey(attempt.quizId, attempt.studentId);
    await _prefs.setString(key, jsonEncode(attempt.toJson()));
  }

  @override
  Future<LocalAttemptModel?> loadActiveAttempt(
    String quizId,
    String studentId,
  ) async {
    final key = _getActiveAttemptKey(quizId, studentId);
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LocalAttemptModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearActiveAttempt(String quizId, String studentId) async {
    final key = _getActiveAttemptKey(quizId, studentId);
    await _prefs.remove(key);
    // Also clean up legacy draft key
    await clearActiveExamDraft(quizId: quizId, studentId: studentId);
  }

  // ==========================================
  // COMPLETED & PENDING ATTEMPTS
  // ==========================================

  @override
  Future<void> saveCompletedAttempt(LocalAttemptModel attempt) async {
    final key = _getCompletedAttemptKey(attempt.attemptId);
    await _prefs.setString(key, jsonEncode(attempt.toJson()));

    // Record under student list
    final studentKey = _getStudentAttemptsKey(attempt.studentId);
    final studentAttemptIds = _prefs.getStringList(studentKey) ?? [];
    if (!studentAttemptIds.contains(attempt.attemptId)) {
      studentAttemptIds.add(attempt.attemptId);
      await _prefs.setStringList(studentKey, studentAttemptIds);
    }

    // Update pending sync list
    final pendingIds = _prefs.getStringList(_keyPendingAttemptIds) ?? [];
    if (attempt.status == AttemptSyncStatus.synced) {
      pendingIds.remove(attempt.attemptId);
    } else {
      if (!pendingIds.contains(attempt.attemptId)) {
        pendingIds.add(attempt.attemptId);
      }
    }
    await _prefs.setStringList(_keyPendingAttemptIds, pendingIds);
  }

  @override
  Future<List<LocalAttemptModel>> getPendingAttempts() async {
    final pendingIds = _prefs.getStringList(_keyPendingAttemptIds) ?? [];
    final List<LocalAttemptModel> list = [];
    for (final id in pendingIds) {
      final key = _getCompletedAttemptKey(id);
      final raw = _prefs.getString(key);
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          final attempt = LocalAttemptModel.fromJson(json);
          if (attempt.status != AttemptSyncStatus.synced) {
            list.add(attempt);
          }
        } catch (_) {}
      }
    }
    return list;
  }

  @override
  Future<List<LocalAttemptModel>> getCompletedAttempts(String studentId) async {
    final studentKey = _getStudentAttemptsKey(studentId);
    final ids = _prefs.getStringList(studentKey) ?? [];
    final List<LocalAttemptModel> list = [];
    for (final id in ids) {
      final key = _getCompletedAttemptKey(id);
      final raw = _prefs.getString(key);
      if (raw != null) {
        try {
          final json = jsonDecode(raw) as Map<String, dynamic>;
          list.add(LocalAttemptModel.fromJson(json));
        } catch (_) {}
      }
    }
    return list;
  }

  @override
  Future<void> updateAttemptStatus(
    String attemptId,
    AttemptSyncStatus status, {
    String? error,
  }) async {
    final key = _getCompletedAttemptKey(attemptId);
    final raw = _prefs.getString(key);
    if (raw == null) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final model = LocalAttemptModel.fromJson(json);
      final updated = model.copyWith(
        status: status,
        lastSyncError: error,
        lastSyncAttempt: DateTime.now(),
        syncRetryCount:
            status == AttemptSyncStatus.syncFailed
                ? model.syncRetryCount + 1
                : model.syncRetryCount,
      );
      await saveCompletedAttempt(LocalAttemptModel.fromEntity(updated));
    } catch (_) {}
  }
}
