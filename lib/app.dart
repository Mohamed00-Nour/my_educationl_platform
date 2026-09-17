import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/services/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'features/admin_dashboard/presentation/screens/teacher_dashboard_screen.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/widgets/role_guard_widget.dart';
import 'features/courses/presentation/bloc/course_bloc.dart';
import 'features/courses/presentation/screens/student_main_screen.dart';
import 'features/notifications/data/services/fcm_service.dart';
import 'features/notifications/presentation/services/notification_navigation_service.dart';
import 'features/quizzes/presentation/blocs/ai_import_bloc.dart';
import 'features/courses/domain/repositories/course_repository.dart';
import 'features/quizzes/domain/repositories/quiz_repository.dart';

import 'features/quizzes/data/services/attempt_sync_service.dart';

class InstructorApp extends StatefulWidget {
  const InstructorApp({super.key});

  @override
  State<InstructorApp> createState() => _InstructorAppState();
}

class _InstructorAppState extends State<InstructorApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;
  late final NotificationNavigationService _notificationNavigationService;
  bool _isOpeningNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationNavigationService = NotificationNavigationService(
      courseRepository: getIt<CourseRepository>(),
      quizRepository: getIt<QuizRepository>(),
    );
    _notificationTapSubscription = getIt<FCMService>().notificationTaps.listen(
      _openNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<AttemptSyncService>().syncPendingAttempts();
    });
  }

  Future<void> _openNotification(Map<String, dynamic> payload) async {
    if (_isOpeningNotification) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final authState = BlocProvider.of<AuthBloc>(navigator.context).state;
    if (authState is! Authenticated) return;

    _isOpeningNotification = true;
    try {
      await _notificationNavigationService.open(
        navigator: navigator,
        user: authState.user,
        payload: payload,
      );
    } on NotificationNavigationException catch (error) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      final context = _navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح محتوى هذا الإشعار.')),
        );
      }
    } finally {
      _isOpeningNotification = false;
    }
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      getIt<AttemptSyncService>().syncPendingAttempts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(AuthCheckRequested()),
        ),
        BlocProvider<CourseBloc>(
          create:
              (_) =>
                  getIt<CourseBloc>()
                    ..add(const FetchCoursesRequested())
                    ..add(const StreamCoursesRequested()),
        ),
        BlocProvider<AIImportBloc>(create: (_) => getIt<AIImportBloc>()),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'المنصة التعليمية',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _AppRouter(),
      ),
    );
  }
}

class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          // Keep this device subscribed only to the student's enrolled courses.
          getIt<FCMService>().initializeForUser(state.user);
          // Sync any pending offline attempts for this student
          getIt<AttemptSyncService>().syncPendingAttempts();
        } else if (state is Unauthenticated) {
          getIt<FCMService>().clearForSignedOutUser();
        }
      },
      builder: (context, state) {
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is Authenticated) {
          return RoleGuardWidget(
            adminBuilder: (ctx, admin) => TeacherDashboardScreen(user: admin),
            studentBuilder: (ctx, student) => StudentMainScreen(user: student),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
