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
  final String? openingLine;
  final String? avatarPath;
  final String? chatBackground;
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
    this.openingLine,
    this.avatarPath,
    this.chatBackground,
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
      'opening_line': openingLine,
      'avatar_path': avatarPath,
      'chat_background': chatBackground,
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
      openingLine: map['opening_line'] as String?,
      avatarPath: map['avatar_path'] as String?,
      chatBackground: map['chat_background'] as String?,
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
    String? openingLine,
    String? avatarPath,
    String? chatBackground,
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
      openingLine: openingLine ?? this.openingLine,
      avatarPath: avatarPath ?? this.avatarPath,
      chatBackground: chatBackground ?? this.chatBackground,
      affection: affection ?? this.affection,
      mode: mode ?? this.mode,
    );
  }
}
