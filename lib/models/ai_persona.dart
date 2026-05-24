import 'package:uuid/uuid.dart';

class AIPersona {
  final String id;
  final String conversationId;
  String name;
  String identity;
  String personality;
  String appearance;
  String notes;
  double affection;
  final DateTime createdAt;

  AIPersona({
    String? id,
    this.conversationId = '',
    this.name = '',
    this.identity = '',
    this.personality = '',
    this.appearance = '',
    this.notes = '',
    this.affection = 30.0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  String buildPrompt() {
    final sb = StringBuffer();
    if (name.isNotEmpty) {
      sb.writeln('你是「$name」。');
    }
    if (identity.isNotEmpty) {
      sb.writeln();
      sb.writeln('【身份】$identity');
    }
    if (personality.isNotEmpty) {
      sb.writeln();
      sb.writeln('【性格习惯】$personality');
    }
    if (appearance.isNotEmpty) {
      sb.writeln();
      sb.writeln('【外观外貌】$appearance');
    }
    if (notes.isNotEmpty) {
      sb.writeln();
      sb.writeln('【补充信息】$notes');
    }
    return sb.toString().trim();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'name': name,
      'identity': identity,
      'personality': personality,
      'appearance': appearance,
      'notes': notes,
      'affection': affection,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AIPersona.fromMap(Map<String, dynamic> map) {
    return AIPersona(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      name: (map['name'] as String?) ?? '',
      identity: (map['identity'] as String?) ?? '',
      personality: (map['personality'] as String?) ?? '',
      appearance: (map['appearance'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      affection: (map['affection'] as num?)?.toDouble() ?? 30.0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
