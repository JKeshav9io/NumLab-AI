import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:numlab_frontend/core/network/dio_client.dart';
import 'package:numlab_frontend/core/router/app_router.dart';
import 'package:numlab_frontend/core/storage/secure_storage_service.dart';
import 'package:numlab_frontend/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:numlab_frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:numlab_frontend/features/auth/domain/repositories/auth_repository.dart';
import 'package:numlab_frontend/features/auth/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/auth/presentation/bloc/bloc.dart';
import 'package:numlab_frontend/features/solvers/data/datasources/solver_remote_data_source.dart';
import 'package:numlab_frontend/features/solvers/data/repositories/solver_repository_impl.dart';
import 'package:numlab_frontend/features/solvers/domain/repositories/solver_repository.dart';
import 'package:numlab_frontend/features/solvers/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/solvers/presentation/bloc/bloc.dart';

/// Global service locator instance.
final GetIt sl = GetIt.instance;

/// Bootstraps dependency injection across all layers.
/// Must be invoked in the app entrypoint before runApp.
Future<void> initDependencies() async {
  // 1. Core Utilities & Logging
  sl
    ..registerLazySingleton<Logger>(
      () => Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
        ),
      ),
    )
    // 2. Storage Layer
    ..registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      ),
    )
    ..registerLazySingleton<SecureStorageService>(
      () => SecureStorageServiceImpl(storage: sl<FlutterSecureStorage>()),
    )
    // 3. Network Layer
    ..registerLazySingleton<Dio>(
      () => DioClient.create(
        secureStorageService: sl<SecureStorageService>(),
        onSessionRevoked: () {
          if (sl.isRegistered<AuthBloc>()) {
            sl<AuthBloc>().add(const AuthSessionRevoked());
          }
        },
      ),
    )
    // 4. Auth Feature (Data, Domain, and Presentation BLoC)
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(dio: sl<Dio>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remoteDataSource: sl<AuthRemoteDataSource>()),
    )
    ..registerLazySingleton<RegisterUseCase>(
      () => RegisterUseCase(sl<AuthRepository>()),
    )
    ..registerLazySingleton<LoginUseCase>(
      () => LoginUseCase(sl<AuthRepository>()),
    )
    ..registerLazySingleton<RefreshTokenUseCase>(
      () => RefreshTokenUseCase(sl<AuthRepository>()),
    )
    ..registerLazySingleton<LogoutUseCase>(
      () => LogoutUseCase(sl<AuthRepository>()),
    )
    ..registerLazySingleton<LogoutAllUseCase>(
      () => LogoutAllUseCase(sl<AuthRepository>()),
    )
    ..registerLazySingleton<GetCurrentUserUseCase>(
      () => GetCurrentUserUseCase(sl<AuthRepository>()),
    )
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(
        secureStorageService: sl<SecureStorageService>(),
        loginUseCase: sl<LoginUseCase>(),
        registerUseCase: sl<RegisterUseCase>(),
        refreshTokenUseCase: sl<RefreshTokenUseCase>(),
        logoutUseCase: sl<LogoutUseCase>(),
        logoutAllUseCase: sl<LogoutAllUseCase>(),
        getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
      ),
    )
    // 5. Routing (Protected by AuthBloc)
    ..registerLazySingleton<AppRouter>(
      () => AppRouter(authBloc: sl<AuthBloc>()),
    )
    // 6. Solvers Feature (Data & Domain)
    ..registerLazySingleton<SolverRemoteDataSource>(
      () => SolverRemoteDataSourceImpl(dio: sl<Dio>()),
    )
    ..registerLazySingleton<SolverRepository>(
      () => SolverRepositoryImpl(
        remoteDataSource: sl<SolverRemoteDataSource>(),
        secureStorageService: sl<SecureStorageService>(),
      ),
    )
    ..registerLazySingleton<ExecuteSolverUseCase>(
      () => ExecuteSolverUseCase(sl<SolverRepository>()),
    )
    ..registerFactory<SolverFormBloc>(
      () => SolverFormBloc(
        executeSolverUseCase: sl<ExecuteSolverUseCase>(),
      ),
    );
}
