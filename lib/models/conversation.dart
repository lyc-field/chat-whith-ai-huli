import 'message.dart';

class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message> messages;
  final String? systemPrompt;
  final String? userPersona;
  final String? worldBackground;
  final String? avatarPath;
  final int affection;
  final String mode; // 'summary' or 'bookmark'

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.systemPrompt,
    this.userPersona,
    this.worldBackground,
    this.avatarPath,
    this.affection = 30,
    this.mode = 'summary',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'system_prompt': systemPrompt,
      'user_persona': userPersona,
      'world_background': worldBackground,
      'avatar_path': avatarPath,
      'affection': affection,
      'mode': mode,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      systemPrompt: map['system_prompt'] as String?,
      userPersona: map['user_persona'] as String?,
      worldBackground: map['world_background'] as String?,
      avatarPath: map['avatar_path'] as String?,
      affection: map['affection'] as int? ?? 30,
      mode: (map['mode'] as String?) ?? 'summary',
    );
  }

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<Message>? messages,
    String? systemPrompt,
    String? userPersona,
    String? worldBackground,
    String? avatarPath,
    int? affection,
    String? mode,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      userPersona: userPersona ?? this.userPersona,
      worldBackground: worldBackground ?? this.worldBackground,
      avatarPath: avatarPath ?? this.avatarPath,
      affection: affection ?? this.affection,
      mode: mode ?? this.mode,
    );
  }
}
