import 'package:numlab_frontend/features/history/domain/entities/history_explanation.dart';

/// Data model representing an AI pedagogical explanation associated with a solver run.
class AiExplanationModel extends HistoryExplanation {
  const AiExplanationModel({
    required super.id,
    required super.responseText,
    required super.createdAt,
    super.solverRunId,
    super.userId,
    super.focusMode = 'steps',
    super.promptHash,
    super.expiresAt,
  });

  /// Parses [AiExplanationModel] from JSON map.
  factory AiExplanationModel.fromJson(Map<String, dynamic> json) {
    return AiExplanationModel(
      id: json['id']?.toString() ?? '',
      solverRunId:
          json['solverRunId']?.toString() ?? json['solver_run_id']?.toString(),
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      focusMode:
          json['focusMode']?.toString() ??
          json['focus_mode']?.toString() ??
          'steps',
      promptHash:
          json['promptHash']?.toString() ?? json['prompt_hash']?.toString(),
      responseText:
          json['responseText']?.toString() ??
          json['response_text']?.toString() ??
          '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : (json['expires_at'] != null
                ? DateTime.tryParse(json['expires_at'].toString())
                : null),
      createdAt:
          DateTime.tryParse(
            json['createdAt']?.toString() ??
                json['created_at']?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }

  /// Constructs an [AiExplanationModel] from a domain [HistoryExplanation] entity.
  factory AiExplanationModel.fromEntity(HistoryExplanation entity) {
    return AiExplanationModel(
      id: entity.id,
      solverRunId: entity.solverRunId,
      userId: entity.userId,
      focusMode: entity.focusMode,
      promptHash: entity.promptHash,
      responseText: entity.responseText,
      expiresAt: entity.expiresAt,
      createdAt: entity.createdAt,
    );
  }

  /// Converts this data model to a domain [HistoryExplanation] entity.
  HistoryExplanation toEntity() {
    return HistoryExplanation(
      id: id,
      solverRunId: solverRunId,
      userId: userId,
      focusMode: focusMode,
      promptHash: promptHash,
      responseText: responseText,
      expiresAt: expiresAt,
      createdAt: createdAt,
    );
  }

  /// Serializes to JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      if (solverRunId != null) 'solverRunId': solverRunId,
      if (userId != null) 'userId': userId,
      'focusMode': focusMode,
      if (promptHash != null) 'promptHash': promptHash,
      'responseText': responseText,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
