enum StudentGrade {
  firstSecondary, // أولى ثانوي
  secondSecondary; // تانية ثانوي

  static StudentGrade? fromString(String? val) {
    if (val == null) return null;
    final clean = val.toLowerCase().trim();
    if (clean == 'firstsecondary' ||
        clean == 'first' ||
        clean == '1' ||
        val.contains('أولى') ||
        val.contains('الاول') ||
        val.contains('الأول')) {
      return StudentGrade.firstSecondary;
    }
    if (clean == 'secondsecondary' ||
        clean == 'second' ||
        clean == '2' ||
        val.contains('تانية') ||
        val.contains('ثانية') ||
        val.contains('الثاني')) {
      return StudentGrade.secondSecondary;
    }
    return null;
  }

  String toValue() => name;

  String toArabicDisplay() {
    switch (this) {
      case StudentGrade.firstSecondary:
        return 'أولى ثانوي';
      case StudentGrade.secondSecondary:
        return 'تانية ثانوي';
    }
  }

  String toFormalArabic() {
    switch (this) {
      case StudentGrade.firstSecondary:
        return 'الصف الأول الثانوي';
      case StudentGrade.secondSecondary:
        return 'الصف الثاني الثانوي';
    }
  }
}

class AppConstants {
  static const String appName = 'Instructor';
  static const String appNameArabic = 'المنصة التعليمية';
  static const String appTagline = 'Secondary School Programming Academy';
  static const String appTaglineArabic =
      'أكاديمية البرمجة لطلاب المرحلة الثانوية';

  // Local Storage Keys
  static const String keyActiveAttemptPrefix = 'active_exam_attempt_';
  static const String keyCachedUser = 'cached_user_profile';
  static const String keyUserRole = 'user_role';

  // Question Types
  static const String typeMcq = 'mcq';
  static const String typeTrueFalse = 'trueFalse';

  // Roles
  static const String roleSuperAdmin = 'superAdmin';
  static const String roleAdmin = 'admin';
  static const String roleStudent = 'student';

  // Attendance Statuses
  static const String attendancePresent = 'present';
  static const String attendanceAbsent = 'absent';
  static const String attendanceLate = 'late';

  // Evaluation Types
  static const String evalBonus = 'bonus';
  static const String evalMinus = 'minus';

  // Explanations Visibility Rules
  static const String explanationAfterSubmission = 'after_submission';
  static const String explanationAfterExamEnds = 'after_exam_ends';
  static const String explanationNever = 'never';

  // Default Weights for Student Progress
  static const double defaultAttendanceWeight = 0.20; // 20%
  static const double defaultQuizWeight = 0.35; // 35%
  static const double defaultExamWeight = 0.45; // 45%
}

class FirestoreCollections {
  static const String users = 'users';
  static const String courses = 'courses';
  static const String units = 'units';
  static const String lessons = 'lessons';
  static const String quizzes = 'quizzes';
  static const String examAttempts = 'exam_attempts';
  static const String questionBank = 'question_bank';
  static const String attendance = 'attendance';
  static const String evaluations = 'evaluations';
  static const String notificationsQueue = 'notifications_queue';
  static const String summaries = 'summaries';
  static const String adminJoinCodes = 'admin_join_codes';
}
