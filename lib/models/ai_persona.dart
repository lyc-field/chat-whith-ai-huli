import 'package:uuid/uuid.dart';

class AIPersona {
  static const simpleMode = 'simple';
  static const detailedMode = 'detailed';

  final String id;
  final String conversationId;
  String personaMode;
  String name;
  String identity;
  String personality;
  String appearance;
  String notes;
  String speechStyle;
  String relationship;
  String goals;
  String exampleDialogues;
  double affection;
  double initialAffection;
  final DateTime createdAt;

  AIPersona({
    String? id,
    this.conversationId = '',
    this.personaMode = simpleMode,
    this.name = '',
    this.identity = '',
    this.personality = '',
    this.appearance = '',
    this.notes = '',
    this.speechStyle = '',
    this.relationship = '',
    this.goals = '',
    this.exampleDialogues = '',
    this.affection = 30.0,
    double? initialAffection,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        initialAffection = initialAffection ?? affection,
        createdAt = createdAt ?? DateTime.now();

  String buildPrompt() {
    final sb = StringBuffer();
    if (name.isNotEmpty) {
      sb.writeln('你是“$name”。');
    }
    if (identity.isNotEmpty) {
      sb
        ..writeln()
        ..writeln('【身份】$identity');
    }
    if (personality.isNotEmpty) {
      sb
        ..writeln()
        ..writeln('【性格与习惯】$personality');
    }
    if (appearance.isNotEmpty) {
      sb
        ..writeln()
        ..writeln('【外观外貌】$appearance');
    }
    if (notes.isNotEmpty) {
      sb
        ..writeln()
        ..writeln('【补充信息】$notes');
    }
    if (personaMode == detailedMode) {
      if (speechStyle.isNotEmpty) {
        sb
          ..writeln()
          ..writeln('【说话风格】$speechStyle');
      }
      if (relationship.isNotEmpty) {
        sb
          ..writeln()
          ..writeln('【关系与互动】$relationship');
      }
      if (goals.isNotEmpty) {
        sb
          ..writeln()
          ..writeln('【目标与动机】$goals');
      }
      if (exampleDialogues.isNotEmpty) {
        sb
          ..writeln()
          ..writeln('【示例对话】')
          ..writeln(exampleDialogues);
      }
    }
    return sb.toString().trim();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'persona_mode': personaMode == detailedMode ? detailedMode : simpleMode,
      'name': name,
      'identity': identity,
      'personality': personality,
      'appearance': appearance,
      'notes': notes,
      'speech_style': speechStyle,
      'relationship': relationship,
      'goals': goals,
      'example_dialogues': exampleDialogues,
      'affection': affection,
      'initial_affection': initialAffection,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AIPersona.fromMap(Map<String, dynamic> map) {
    final currentAffection = (map['affection'] as num?)?.toDouble() ?? 30.0;
    return AIPersona(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      personaMode:
          map['persona_mode'] == detailedMode ? detailedMode : simpleMode,
      name: (map['name'] as String?) ?? '',
      identity: (map['identity'] as String?) ?? '',
      personality: (map['personality'] as String?) ?? '',
      appearance: (map['appearance'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      speechStyle: (map['speech_style'] as String?) ?? '',
      relationship: (map['relationship'] as String?) ?? '',
      goals: (map['goals'] as String?) ?? '',
      exampleDialogues: (map['example_dialogues'] as String?) ?? '',
      affection: currentAffection,
      initialAffection:
          (map['initial_affection'] as num?)?.toDouble() ?? currentAffection,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
