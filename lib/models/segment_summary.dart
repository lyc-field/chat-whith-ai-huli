import 'package:uuid/uuid.dart';

class SegmentSummary {
  final String id;
  final String conversationId;
  final String content;
  final int segmentIndex;
  final int? roundStart;
  final int? roundEnd;
  final String? startMessageId;
  final String? endMessageId;
  final DateTime createdAt;

  SegmentSummary({
    String? id,
    required this.conversationId,
    this.content = '',
    required this.segmentIndex,
    this.roundStart,
    this.roundEnd,
    this.startMessageId,
    this.endMessageId,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  int get effectiveRoundStart => roundStart ?? (segmentIndex * 8 + 1);
  int get effectiveRoundEnd => roundEnd ?? ((segmentIndex + 1) * 8);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'content': content,
      'segment_index': segmentIndex,
      'round_start': roundStart,
      'round_end': roundEnd,
      'start_message_id': startMessageId,
      'end_message_id': endMessageId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SegmentSummary.fromMap(Map<String, dynamic> map) {
    return SegmentSummary(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      content: map['content'] as String? ?? '',
      segmentIndex: (map['segment_index'] as num).toInt(),
      roundStart: (map['round_start'] as num?)?.toInt(),
      roundEnd: (map['round_end'] as num?)?.toInt(),
      startMessageId: map['start_message_id'] as String?,
      endMessageId: map['end_message_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  SegmentSummary copyWith({
    String? content,
    int? roundStart,
    int? roundEnd,
    String? startMessageId,
    String? endMessageId,
  }) {
    return SegmentSummary(
      id: id,
      conversationId: conversationId,
      content: content ?? this.content,
      segmentIndex: segmentIndex,
      roundStart: roundStart ?? this.roundStart,
      roundEnd: roundEnd ?? this.roundEnd,
      startMessageId: startMessageId ?? this.startMessageId,
      endMessageId: endMessageId ?? this.endMessageId,
      createdAt: createdAt,
    );
  }
}
