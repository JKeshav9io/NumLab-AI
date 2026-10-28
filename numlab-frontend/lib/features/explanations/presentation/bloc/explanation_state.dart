import 'package:equatable/equatable.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/explanations/domain/entities/entities.dart';

/// Sealed hierarchy of all states emitted by `ExplanationBloc`.
sealed class ExplanationState extends Equatable {
  const ExplanationState();

  /// Convenient accessor for any available explanation across states.
  AiExplanationResult? get currentExplanation => switch (this) {
    ExplanationSuccess(:final explanation) => explanation,
    ExplanationLoading(:final previousExplanation) => previousExplanation,
    ExplanationFailure(:final previousExplanation) => previousExplanation,
    _ => null,
  };

  @override
  List<Object?> get props => [];
}

/// Initial state before any explanation has been requested.
final class ExplanationInitial extends ExplanationState {
  const ExplanationInitial();
}

/// State emitted while an explanation request is actively running.
final class ExplanationLoading extends ExplanationState {
  const ExplanationLoading({this.previousExplanation, this.isSlow = false});

  /// Whether the request has remained pending long enough for extra feedback.
  final bool isSlow;

  /// Previous explanation preserved while refreshing or changing focus mode.
  final AiExplanationResult? previousExplanation;

  @override
  List<Object?> get props => [previousExplanation, isSlow];
}

/// State emitted upon a successful AI explanation request.
final class ExplanationSuccess extends ExplanationState {
  const ExplanationSuccess({
    required this.explanation,
  });

  /// The resulting AI explanation entity.
  final AiExplanationResult explanation;

  @override
  List<Object?> get props => [explanation];
}

/// State emitted when an explanation request fails.
final class ExplanationFailure extends ExplanationState {
  const ExplanationFailure({
    required this.failure,
    this.previousExplanation,
  });

  /// The domain failure describing the error.
  final Failure failure;

  /// Maintained previous explanation to keep content visible during non-fatal errors.
  final AiExplanationResult? previousExplanation;

  /// Whether failure is a 429 rate limit error.
  bool get isRateLimit => failure is RateLimitFailure;

  /// Whether failure is a network or connectivity issue.
  bool get isNetwork => failure is NetworkFailure;

  /// Whether the network failure was caused by a request timeout.
  bool get isTimeout => isNetwork && failure.code == 'REQUEST_TIMEOUT';

  /// Whether failure is an authentication issue.
  bool get isAuth => failure is AuthFailure;

  /// Whether failure is a validation issue.
  bool get isValidation => failure is ValidationFailure;

  /// Whether failure is an internal server error.
  bool get isServer => failure is ServerFailure;

  /// Retry cooldown in seconds if provided by rate limit failure.
  int? get retryAfterSeconds => switch (failure) {
    RateLimitFailure(:final retryAfterSeconds) => retryAfterSeconds,
    _ => null,
  };

  /// User-friendly error message.
  String get message => failure.message;

  @override
  List<Object?> get props => [failure, previousExplanation];
}
