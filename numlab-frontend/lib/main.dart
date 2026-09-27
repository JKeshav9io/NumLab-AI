import 'package:flutter/material.dart';
import 'package:numlab_frontend/app.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/injection_container.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize service locator and core infrastructure dependencies
  await initDependencies();

  // Kick off session restoration check on application launch
  sl<AuthBloc>().add(const AuthInitializeRequested());

  runApp(const NumLabApp());
}
