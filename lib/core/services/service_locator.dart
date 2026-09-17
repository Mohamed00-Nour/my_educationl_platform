import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/attendance/data/datasources/attendance_remote_data_source.dart';
import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/presentation/bloc/attendance_bloc.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/join_code_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/join_code_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/join_code_repository.dart';
import '../../features/auth/domain/usecases/get_admins_overview_usecase.dart';
import '../../features/auth/domain/usecases/manage_join_code_usecase.dart';
import '../../features/auth/domain/usecases/transfer_student_usecase.dart';
import '../../features/auth/domain/usecases/validate_join_code_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/cubit/admin_management_cubit.dart';

import '../../features/courses/data/datasources/course_remote_data_source.dart';
import '../../features/courses/data/repositories/course_repository_impl.dart';
import '../../features/courses/domain/repositories/course_repository.dart';
import '../../features/courses/presentation/bloc/course_bloc.dart';

import '../../features/evaluations/data/datasources/evaluation_remote_data_source.dart';
import '../../features/evaluations/data/repositories/evaluation_repository_impl.dart';
import '../../features/evaluations/domain/repositories/evaluation_repository.dart';
import '../../features/evaluations/presentation/bloc/evaluation_bloc.dart';

import '../../features/notifications/data/services/fcm_service.dart';
import '../../features/notifications/data/services/embedded_fcm_sender.dart';
import '../../features/notifications/data/services/notification_queue_service.dart';

import '../../features/progress/data/repositories/progress_repository_impl.dart';
import '../../features/progress/domain/repositories/progress_repository.dart';
import '../../features/progress/presentation/bloc/student_progress_cubit.dart';

import '../../features/quizzes/data/datasources/exam_local_data_source.dart';
import '../../features/quizzes/data/datasources/quiz_remote_data_source.dart';
import '../../features/quizzes/data/repositories/quiz_repository_impl.dart';
import '../../features/quizzes/data/services/attempt_sync_service.dart';
import '../../features/quizzes/domain/repositories/quiz_repository.dart';
import '../../features/quizzes/domain/usecases/validate_ai_questions_usecase.dart';
import '../../features/quizzes/presentation/blocs/ai_import_bloc.dart';
import '../../features/quizzes/presentation/blocs/exam_runner_bloc.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // 1. External & Firebase Instances
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;
  final messaging = FirebaseMessaging.instance;

  getIt.registerSingleton<FirebaseAuth>(auth);
  getIt.registerSingleton<FirebaseFirestore>(firestore);
  getIt.registerSingleton<FirebaseMessaging>(messaging);

  // 2. Data Sources
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: auth, firestore: firestore),
  );
  getIt.registerLazySingleton<JoinCodeRemoteDataSource>(
    () => JoinCodeRemoteDataSourceImpl(firestore: firestore),
  );
  getIt.registerLazySingleton<CourseRemoteDataSource>(
    () => CourseRemoteDataSourceImpl(firestore: firestore),
  );
  getIt.registerLazySingleton<ExamLocalDataSource>(
    () => ExamLocalDataSourceImpl(prefs),
  );
  getIt.registerLazySingleton<QuizRemoteDataSource>(
    () => QuizRemoteDataSourceImpl(firestore: firestore),
  );
  getIt.registerLazySingleton<AttendanceRemoteDataSource>(
    () => AttendanceRemoteDataSourceImpl(firestore: firestore),
  );
  getIt.registerLazySingleton<EvaluationRemoteDataSource>(
    () => EvaluationRemoteDataSourceImpl(firestore: firestore),
  );

  // 3. Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<AuthRemoteDataSource>()),
  );
  getIt.registerLazySingleton<JoinCodeRepository>(
    () => JoinCodeRepositoryImpl(getIt<JoinCodeRemoteDataSource>()),
  );
  getIt.registerLazySingleton<CourseRepository>(
    () => CourseRepositoryImpl(getIt<CourseRemoteDataSource>()),
  );
  getIt.registerLazySingleton<QuizRepository>(
    () => QuizRepositoryImpl(
      remoteDataSource: getIt<QuizRemoteDataSource>(),
      localDataSource: getIt<ExamLocalDataSource>(),
    ),
  );
  getIt.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(getIt<AttendanceRemoteDataSource>()),
  );
  getIt.registerLazySingleton<EvaluationRepository>(
    () => EvaluationRepositoryImpl(getIt<EvaluationRemoteDataSource>()),
  );
  getIt.registerLazySingleton<ProgressRepository>(
    () => ProgressRepositoryImpl(
      attendanceRepository: getIt<AttendanceRepository>(),
      quizRepository: getIt<QuizRepository>(),
      evaluationRepository: getIt<EvaluationRepository>(),
    ),
  );

  // 4. Use Cases & Services
  getIt.registerLazySingleton<ValidateJoinCodeUseCase>(
    () => ValidateJoinCodeUseCase(getIt<JoinCodeRepository>()),
  );
  getIt.registerLazySingleton<ManageJoinCodeUseCase>(
    () => ManageJoinCodeUseCase(getIt<JoinCodeRepository>()),
  );
  getIt.registerLazySingleton<TransferStudentUseCase>(
    () => TransferStudentUseCase(getIt<JoinCodeRepository>()),
  );
  getIt.registerLazySingleton<GetAdminsOverviewUseCase>(
    () => GetAdminsOverviewUseCase(getIt<JoinCodeRepository>()),
  );
  getIt.registerLazySingleton<ValidateAIQuestionsUseCase>(
    () => ValidateAIQuestionsUseCase(),
  );
  getIt.registerLazySingleton<FCMService>(
    () => FCMService(
      messaging: messaging,
      firestore: firestore,
      preferences: prefs,
    ),
  );
  getIt.registerLazySingleton<EmbeddedFcmSender>(() => EmbeddedFcmSender());
  getIt.registerLazySingleton<NotificationQueueService>(
    () => NotificationQueueService(
      firestore: firestore,
      auth: auth,
      sender: getIt<EmbeddedFcmSender>(),
    ),
  );
  getIt.registerLazySingleton<AttemptSyncService>(
    () => AttemptSyncService(getIt<QuizRepository>()),
  );

  // 5. BLoCs / Cubits (Factory registration for clean lifecycle)
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      getIt<AuthRepository>(),
      validateJoinCodeUseCase: getIt<ValidateJoinCodeUseCase>(),
      manageJoinCodeUseCase: getIt<ManageJoinCodeUseCase>(),
    ),
  );
  getIt.registerFactory<AdminManagementCubit>(
    () => AdminManagementCubit(
      manageJoinCodeUseCase: getIt<ManageJoinCodeUseCase>(),
      getAdminsOverviewUseCase: getIt<GetAdminsOverviewUseCase>(),
      transferStudentUseCase: getIt<TransferStudentUseCase>(),
    ),
  );
  getIt.registerFactory<CourseBloc>(
    () => CourseBloc(
      getIt<CourseRepository>(),
      notificationQueueService: getIt<NotificationQueueService>(),
    ),
  );
  getIt.registerFactory<AIImportBloc>(
    () => AIImportBloc(
      validateUseCase: getIt<ValidateAIQuestionsUseCase>(),
      quizRepository: getIt<QuizRepository>(),
    ),
  );
  getIt.registerFactory<ExamRunnerBloc>(
    () => ExamRunnerBloc(getIt<QuizRepository>()),
  );
  getIt.registerFactory<AttendanceBloc>(
    () => AttendanceBloc(getIt<AttendanceRepository>()),
  );
  getIt.registerFactory<EvaluationBloc>(
    () => EvaluationBloc(getIt<EvaluationRepository>()),
  );
  getIt.registerFactory<StudentProgressCubit>(
    () => StudentProgressCubit(getIt<ProgressRepository>()),
  );
}
