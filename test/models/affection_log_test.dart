import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/affection_log.dart';

void main() {
  test(
      'persists detailed reason while keeping legacy message fields compatible',
      () {
    final log = AffectionLog(
      id: 'l1',
      conversationId: 'c1',
      delta: 0.3,
      reason: '用户的耐心让我安心',
      detailedReason: '这四轮互动里，用户持续耐心地回应并主动照顾我的感受，让我感到被认真对待，也更愿意靠近和信任对方。',
      createdAt: DateTime(2026, 1, 1),
    );

    final restored = AffectionLog.fromMap(log.toMap());

    expect(restored.detailedReason, log.detailedReason);
    expect(restored.userMessage, isEmpty);
    expect(restored.aiMessage, isEmpty);
  });

  test('legacy rows without detailed reason remain readable', () {
    final restored = AffectionLog.fromMap({
      'id': 'legacy',
      'conversation_id': 'c1',
      'delta': 0.0,
      'reason': '互动平稳',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    expect(restored.detailedReason, isEmpty);
  });
}
