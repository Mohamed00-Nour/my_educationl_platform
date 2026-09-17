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
import 'features/quizzes/presentation/blocs/ai_import_bloc.dart';

import 'features/quizzes/data/services/attempt_sync_service.dart';

class InstructorApp extends StatefulWidget {
  const InstructorApp({super.key});

  @override
  State<InstructorApp> createState() => _InstructorAppState();
}

class _InstructorAppState extends State<InstructorApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<AttemptSyncService>().syncPendingAttempts();
    });
  }

  @override
  void dispose() {
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
