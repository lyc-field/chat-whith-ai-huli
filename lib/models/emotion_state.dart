import 'package:uuid/uuid.dart';

class EmotionState {
  final String id;
  final String conversationId;
  final String? personaId;
  double affection;
  double currentLibidoOther;
  double baseLibidoOther;
  double currentAggressionOther;
  double baseAggressionOther;
  double currentLibidoSelf;
  double baseLibidoSelf;
  double currentAggressionSelf;
  double baseAggressionSelf;
  int turnCount;
  DateTime lastInteraction;
  DateTime lastUpdate;

  EmotionState({
    required this.id,
    required this.conversationId,
    this.personaId,
    this.affection = 30.0,
    this.currentLibidoOther = 25.0,
    this.baseLibidoOther = 25.0,
    this.currentAggressionOther = 25.0,
    this.baseAggressionOther = 25.0,
    this.currentLibidoSelf = 25.0,
    this.baseLibidoSelf = 25.0,
    this.currentAggressionSelf = 25.0,
    this.baseAggressionSelf = 25.0,
    this.turnCount = 0,
    DateTime? lastInteraction,
    DateTime? lastUpdate,
  })  : lastInteraction = lastInteraction ?? DateTime.now(),
        lastUpdate = lastUpdate ?? DateTime.now();

  static EmotionState createDefault(String conversationId, {double initialAffection = 30.0, String? personaId}) {
    return EmotionState(
      id: const Uuid().v4(),
      conversationId: conversationId,
      personaId: personaId,
      affection: initialAffection,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'persona_id': personaId,
      'affection': affection,
      'current_libido_other': currentLibidoOther,
      'base_libido_other': baseLibidoOther,
      'current_aggression_other': currentAggressionOther,
      'base_aggression_other': baseAggressionOther,
      'current_libido_self': currentLibidoSelf,
      'base_libido_self': baseLibidoSelf,
      'current_aggression_self': currentAggressionSelf,
      'base_aggression_self': baseAggressionSelf,
      'turn_count': turnCount,
      'last_interaction': lastInteraction.toIso8601String(),
      'last_update': lastUpdate.toIso8601String(),
    };
  }

  factory EmotionState.fromMap(Map<String, dynamic> map) {
    return EmotionState(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      personaId: map['persona_id'] as String?,
      affection: (map['affection'] as num).toDouble(),
      currentLibidoOther: (map['current_libido_other'] as num).toDouble(),
      baseLibidoOther: (map['base_libido_other'] as num).toDouble(),
      currentAggressionOther: (map['current_aggression_other'] as num).toDouble(),
      baseAggressionOther: (map['base_aggression_other'] as num).toDouble(),
      currentLibidoSelf: (map['current_libido_self'] as num).toDouble(),
      baseLibidoSelf: (map['base_libido_self'] as num).toDouble(),
      currentAggressionSelf: (map['current_aggression_self'] as num).toDouble(),
      baseAggressionSelf: (map['base_aggression_self'] as num).toDouble(),
      turnCount: map['turn_count'] as int,
      lastInteraction: DateTime.parse(map['last_interaction'] as String),
      lastUpdate: DateTime.parse(map['last_update'] as String),
    );
  }
}

class EmotionLog {
  final String id;
  final String conversationId;
  final String? personaId;
  final double? affectionDelta;
  final double? libidoOtherDelta;
  final double? aggressionOtherDelta;
  final double? libidoSelfDelta;
  final double? aggressionSelfDelta;
  final String? reason;
  final double intensity;
  final DateTime createdAt;
  final String userMessage;
  final String aiMessage;

  EmotionLog({
    required this.id,
    required this.conversationId,
    this.personaId,
    this.affectionDelta,
    this.libidoOtherDelta,
    this.aggressionOtherDelta,
    this.libidoSelfDelta,
    this.aggressionSelfDelta,
    this.reason,
    this.intensity = 1.0,
    DateTime? createdAt,
    this.userMessage = '',
    this.aiMessage = '',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'persona_id': personaId,
      'affection_delta': affectionDelta,
      'libido_other_delta': libidoOtherDelta,
      'aggression_other_delta': aggressionOtherDelta,
      'libido_self_delta': libidoSelfDelta,
      'aggression_self_delta': aggressionSelfDelta,
      'reason': reason,
      'intensity': intensity,
      'created_at': createdAt.toIso8601String(),
      'user_message': userMessage,
      'ai_message': aiMessage,
    };
  }

  factory EmotionLog.fromMap(Map<String, dynamic> map) {
    return EmotionLog(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      personaId: map['persona_id'] as String?,
      affectionDelta: (map['affection_delta'] as num?)?.toDouble(),
      libidoOtherDelta: (map['libido_other_delta'] as num?)?.toDouble(),
      aggressionOtherDelta: (map['aggression_other_delta'] as num?)?.toDouble(),
      libidoSelfDelta: (map['libido_self_delta'] as num?)?.toDouble(),
      aggressionSelfDelta: (map['aggression_self_delta'] as num?)?.toDouble(),
      reason: map['reason'] as String?,
      intensity: (map['intensity'] as num?)?.toDouble() ?? 1.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      userMessage: (map['user_message'] as String?) ?? '',
      aiMessage: (map['ai_message'] as String?) ?? '',
    );
  }
}
