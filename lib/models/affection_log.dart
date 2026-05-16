class AffectionLog {
  final String id;
  final String conversationId;
  final double delta;
  final String reason;
  final DateTime createdAt;
  final String userMessage;
  final String aiMessage;

  AffectionLog({
    required this.id,
    required this.conversationId,
    required this.delta,
    required this.reason,
    required this.createdAt,
    this.userMessage = '',
    this.aiMessage = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'delta': delta,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'user_message': userMessage,
      'ai_message': aiMessage,
    };
  }

  factory AffectionLog.fromMap(Map<String, dynamic> map) {
    return AffectionLog(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      delta: (map['delta'] as num).toDouble(),
      reason: map['reason'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      userMessage: (map['user_message'] as String?) ?? '',
      aiMessage: (map['ai_message'] as String?) ?? '',
    );
  }
}
