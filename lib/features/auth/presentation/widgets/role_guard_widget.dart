import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/user_entity.dart';
import '../bloc/auth_bloc.dart';

class RoleGuardWidget extends StatelessWidget {
  final Widget Function(BuildContext context, UserEntity admin) adminBuilder;
  final Widget Function(BuildContext context, UserEntity student)
  studentBuilder;

  const RoleGuardWidget({
    super.key,
    required this.adminBuilder,
    required this.studentBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          if (state.user.isAdmin) {
            return adminBuilder(context, state.user);
          } else {
            return studentBuilder(context, state.user);
          }
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
