import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/local_attempt_entity.dart';
import '../../domain/repositories/quiz_repository.dart';

class AttemptSyncService {
  final QuizRepository _quizRepository;

  bool _isSyncing = false;
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  AttemptSyncService(this._quizRepository);

  bool get isSyncing => _isSyncing;

  /// Synchronizes all locally completed attempts with Firestore.
  /// Idempotent, safe across crashes/disconnects, and never destroys local pending data.
  Future<int> syncPendingAttempts() async {
    if (_isSyncing) return 0;

    _isSyncing = true;
    isSyncingNotifier.value = true;

    int syncedCount = 0;
    try {
      final pending = await _quizRepository.getPendingAttempts();
      if (pending.isEmpty) {
        return 0;
      }

      for (final attempt in pending) {
        // Only retry if not already marked synced
        if (attempt.status == AttemptSyncStatus.synced) continue;

        try {
          final result = await _quizRepository.syncAttempt(attempt);
          if (result.status == AttemptSyncStatus.synced) {
            syncedCount++;
          }
        } catch (_) {
          // Failure is captured inside syncAttempt and recorded locally
        }
      }
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }

    return syncedCount;
  }
}
