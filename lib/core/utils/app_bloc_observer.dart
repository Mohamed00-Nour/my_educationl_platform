import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Global BLoC Observer for real-time monitoring and robust error reporting
class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    debugPrint('🚨 [BlocError in ${bloc.runtimeType}]: $error');
    debugPrint(stackTrace.toString());
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      debugPrint(
        '🔄 [${bloc.runtimeType}] ${change.currentState.runtimeType} -> ${change.nextState.runtimeType}',
      );
    }
  }
}
