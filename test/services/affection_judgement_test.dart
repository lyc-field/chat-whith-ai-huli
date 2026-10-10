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
    expect(prompt, contains('简单总结'));
  });

  test(
      'normalizes short affection reasons to a non-empty maximum of 20 characters',
      () {
    expect(
      AffectionBatchService.normalizeReason('太短'),
      allOf(isNotEmpty, predicate<String>((s) => s.runes.length <= 20)),
    );
    expect(
      AffectionBatchService.normalizeReason('这是一段非常非常非常非常非常非常非常非常非常非常长的原因说明'),
      predicate<String>((s) => s.runes.length <= 20),
    );
  });

  test('parses detailed reason only for non-zero affection changes', () {
    final positive = AffectionBatchService.parseJudgement(
      '{"affection_delta":0.3,"affection_reason":"用户的耐心让我安心","affection_detail":"这四轮互动里，用户持续耐心地回应并主动照顾我的感受，让我感到被认真对待，也更愿意靠近和信任对方。"}',
    );
    final neutral = AffectionBatchService.parseJudgement(
      '{"affection_delta":0.0,"affection_reason":"互动平稳，没有明显变化","affection_detail":"这段内容不应被保存"}',
    );
    expect(positive.reason.runes.length, lessThanOrEqualTo(20));
    expect(positive.detailedReason.runes.length, inInclusiveRange(30, 120));
    expect(neutral.detailedReason, isEmpty);
  });

  test('keeps malformed JSON fields from leaking a parser error', () {
    final judgement = AffectionBatchService.parseJudgement(
      '{"affection_delta":"not-a-number","affection_reason":null,"affection_detail":123}',
    );

    expect(judgement.delta, 0);
    expect(judgement.reason, isNotEmpty);
    expect(judgement.detailedReason, isEmpty);
  });

  test('maps emotion intensity to safe current-value caps', () {
    expect(EmotionDeltaPolicy.currentDeltaCap(0.5), 0.0);
    expect(EmotionDeltaPolicy.currentDeltaCap(1.0), 0.1);
    expect(EmotionDeltaPolicy.currentDeltaCap(2.0), 2.0);
  });
}
