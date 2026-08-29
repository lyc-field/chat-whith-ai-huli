import 'package:uuid/uuid.dart';

class Message {
  final String id;
  final String conversationId;
  final String role; // 'user', 'assistant', or 'system'
  final String content;
  final int?
      totalTokens; // total tokens spent for this AI turn (prompt + completion)
  final DateTime timestamp;
  final int? segmentIndex; // null = active, non-null = archived segment
  final bool isBookmarked;
  final List<String>? quickReplies; // runtime-only, parsed from AI response

  Message({
    String? id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.totalTokens,
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
      'total_tokens': totalTokens,
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
      totalTokens: map['total_tokens'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      segmentIndex: map['segment_index'] as int?,
      isBookmarked: (map['is_bookmarked'] as int?) == 1,
    );
  }

  Message copyWith({
    String? content,
    int? totalTokens,
    int? segmentIndex,
    bool? isBookmarked,
    List<String>? quickReplies,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content ?? this.content,
      totalTokens: totalTokens ?? this.totalTokens,
      timestamp: timestamp,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      quickReplies: quickReplies ?? this.quickReplies,
    );
  }
}
