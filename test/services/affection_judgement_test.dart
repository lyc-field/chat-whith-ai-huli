import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/affection_batch_service.dart';

void main() {
  test('formats four rounds into a stable batch prompt', () {
    final rounds = [
      const AffectionRound(user: '摸摸你的头', assistant: '耳朵轻轻动了动。'),
      const AffectionRound(user: '今天辛苦了', assistant: '靠近你一点。'),
      const AffectionRound(user: '想听你说话', assistant: '我在这里。'),
      const AffectionRound(user: '别难过', assistant: '我会慢慢平静下来。'),
    ];

    final prompt = AffectionBatchService.buildSummaryPrompt(rounds);

    expect(prompt, contains('第1轮'));
    expect(prompt, contains('第4轮'));
    expect(prompt, contains('先总结'));
  });

  test('normalizes affection reasons to a non-empty 15..30 character range', () {
    expect(
      AffectionBatchService.normalizeReason('太短'),
      allOf(isNotEmpty, predicate<String>((s) => s.runes.length >= 15)),
    );
    expect(
      AffectionBatchService.normalizeReason('这是一段非常非常非常非常非常非常非常非常非常非常长的原因说明'),
      predicate<String>((s) => s.runes.length <= 30),
    );
  });

  test('maps emotion intensity to safe current-value caps', () {
    expect(EmotionDeltaPolicy.currentDeltaCap(0.5), 0.0);
    expect(EmotionDeltaPolicy.currentDeltaCap(1.0), 0.1);
    expect(EmotionDeltaPolicy.currentDeltaCap(2.0), 2.0);
  });
}
