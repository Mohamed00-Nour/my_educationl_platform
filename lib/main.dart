import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app.dart';
import 'core/services/service_locator.dart';
import 'core/utils/app_bloc_observer.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Global BLoC Observer for error logging and monitoring
  Bloc.observer = AppBlocObserver();

  // Initialize Firebase with CLI-configured options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Dependency Injection Service Locator
  await setupServiceLocator();

  runApp(const InstructorApp());
}
