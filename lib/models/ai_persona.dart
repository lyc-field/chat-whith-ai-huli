import 'package:uuid/uuid.dart';

class AIPersona {
  final String id;
  final String conversationId;
  String name;
  String personality;
  String habits;
  String appearance;
  String background;
  String openingLine;
  double affection;
  final DateTime createdAt;

  AIPersona({
    String? id,
    this.conversationId = '',
    this.name = '',
    this.personality = '',
    this.habits = '',
    this.appearance = '',
    this.background = '',
    this.openingLine = '',
    this.affection = 30.0,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  String buildPrompt() {
    final sb = StringBuffer();
    if (name.isNotEmpty) {
      sb.writeln('你是「$name」。');
    }
    if (personality.isNotEmpty) {
      sb.writeln();
      sb.writeln('【性格】$personality');
    }
    if (habits.isNotEmpty) {
      sb.writeln();
      sb.writeln('【习惯】$habits');
    }
    if (appearance.isNotEmpty) {
      sb.writeln();
      sb.writeln('【外观】$appearance');
    }
    if (background.isNotEmpty) {
      sb.writeln();
      sb.writeln('【背景】$background');
    }
    if (openingLine.isNotEmpty) {
      sb.writeln();
      sb.writeln('【开局剧情】$openingLine');
    }
    return sb.toString().trim();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'name': name,
      'personality': personality,
      'habits': habits,
      'appearance': appearance,
      'background': background,
      'opening_line': openingLine,
      'affection': affection,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AIPersona.fromMap(Map<String, dynamic> map) {
    return AIPersona(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      name: (map['name'] as String?) ?? '',
      personality: (map['personality'] as String?) ?? '',
      habits: (map['habits'] as String?) ?? '',
      appearance: (map['appearance'] as String?) ?? '',
      background: (map['background'] as String?) ?? '',
      openingLine: (map['opening_line'] as String?) ?? '',
      affection: (map['affection'] as num?)?.toDouble() ?? 30.0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
