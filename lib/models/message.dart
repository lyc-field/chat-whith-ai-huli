import 'package:uuid/uuid.dart';

class Message {
  final String id;
  final String conversationId;
  final String role; // 'user', 'assistant', or 'system'
  final String content;
  final DateTime timestamp;
  final int? segmentIndex; // null = active, non-null = archived segment
  final bool isBookmarked;
  final List<String>? quickReplies; // runtime-only, parsed from AI response

  Message({
    String? id,
    required this.conversationId,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.segmentIndex,
    this.isBookmarked = false,
    this.quickReplies,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'segment_index': segmentIndex,
      'is_bookmarked': isBookmarked ? 1 : 0,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      segmentIndex: map['segment_index'] as int?,
      isBookmarked: (map['is_bookmarked'] as int?) == 1,
    );
  }

  Message copyWith({String? content, int? segmentIndex, bool? isBookmarked, List<String>? quickReplies}) {
    return Message(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      quickReplies: quickReplies ?? this.quickReplies,
    );
  }
}
