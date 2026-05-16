import 'package:uuid/uuid.dart';

class SegmentSummary {
  final String id;
  final String conversationId;
  final String content;
  final int segmentIndex;
  final DateTime createdAt;

  SegmentSummary({
    String? id,
    required this.conversationId,
    this.content = '',
    required this.segmentIndex,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'content': content,
      'segment_index': segmentIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SegmentSummary.fromMap(Map<String, dynamic> map) {
    return SegmentSummary(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      content: map['content'] as String? ?? '',
      segmentIndex: map['segment_index'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  SegmentSummary copyWith({String? content}) {
    return SegmentSummary(
      id: id,
      conversationId: conversationId,
      content: content ?? this.content,
      segmentIndex: segmentIndex,
      createdAt: createdAt,
    );
  }
}
