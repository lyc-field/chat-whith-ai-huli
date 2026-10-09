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
    );

    final restored = SegmentSummary.fromMap(summary.toMap());

    expect(restored.roundStart, 17);
    expect(restored.roundEnd, 24);
    expect(restored.startMessageId, 'm17');
    expect(restored.endMessageId, 'm24');
  });

  test('old summary maps expose an eight-round fallback range', () {
    final summary = SegmentSummary(
      conversationId: 'c1',
      segmentIndex: 1,
    );

    expect(summary.effectiveRoundStart, 9);
    expect(summary.effectiveRoundEnd, 16);
  });
}
