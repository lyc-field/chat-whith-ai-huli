import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/segment_summary.dart';

void main() {
  test('summary preserves exact round and message boundaries', () {
    final summary = SegmentSummary(
      conversationId: 'c1',
      segmentIndex: 2,
      roundStart: 17,
      roundEnd: 24,
      startMessageId: 'm17',
      endMessageId: 'm24',
      manuallyEdited: true,
    );

    final restored = SegmentSummary.fromMap(summary.toMap());

    expect(restored.roundStart, 17);
    expect(restored.roundEnd, 24);
    expect(restored.startMessageId, 'm17');
    expect(restored.endMessageId, 'm24');
    expect(restored.manuallyEdited, isTrue);
  });

  test('old summary maps expose an eight-round fallback range', () {
    final summary = SegmentSummary(
      conversationId: 'c1',
      segmentIndex: 1,
    );

    expect(summary.effectiveRoundStart, 9);
    expect(summary.effectiveRoundEnd, 16);
  });

  test('old persisted summaries default to not manually edited', () {
    final summary = SegmentSummary.fromMap({
      'id': 'legacy',
      'conversation_id': 'c1',
      'content': 'legacy content',
      'segment_index': 0,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    expect(summary.manuallyEdited, isFalse);
  });
}
