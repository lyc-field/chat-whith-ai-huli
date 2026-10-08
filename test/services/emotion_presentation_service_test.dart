import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/emotion_state.dart';
import 'package:chat_app/services/emotion_presentation_service.dart';

void main() {
  group('EmotionPresentationService.relationshipStageFor', () {
    test('maps affection into user-facing relationship stages', () {
      expect(
        EmotionPresentationService.relationshipStageFor(-5),
        '敌意',
      );
      expect(
        EmotionPresentationService.relationshipStageFor(10),
        '陌生',
      );
      expect(
        EmotionPresentationService.relationshipStageFor(30),
        '熟悉',
      );
      expect(
        EmotionPresentationService.relationshipStageFor(55),
        '亲近',
      );
      expect(
        EmotionPresentationService.relationshipStageFor(75),
        '亲密',
      );
      expect(
        EmotionPresentationService.relationshipStageFor(95),
        '深爱',
      );
    });
  });

  group('EmotionPresentationService.summarize', () {
    test('returns readable emotion labels and a stable trend at baseline', () {
      final state = EmotionState(
        id: 'state-1',
        conversationId: 'conversation-1',
        affection: 30,
      );

      final presentation = EmotionPresentationService.summarize(state);

      expect(presentation.relationshipStage, '熟悉');
      expect(presentation.towardsUserEmotion, isNotEmpty);
      expect(presentation.selfEmotion, isNotEmpty);
      expect(presentation.trend, '相对稳定');
      expect(presentation.summary, contains(presentation.towardsUserEmotion));
    });

    test(
        'describes a warmer relationship when positive feelings exceed aggression',
        () {
      final state = EmotionState(
        id: 'state-2',
        conversationId: 'conversation-2',
        affection: 70,
        currentLibidoOther: 40,
        baseLibidoOther: 25,
        currentAggressionOther: 10,
        baseAggressionOther: 25,
      );

      final presentation = EmotionPresentationService.summarize(state);

      expect(presentation.relationshipStage, '亲密');
      expect(presentation.trend, '正在升温');
      expect(presentation.trendDescription, contains('靠近'));
    });

    test(
        'describes a cooling relationship when aggression exceeds positive feelings',
        () {
      final state = EmotionState(
        id: 'state-3',
        conversationId: 'conversation-3',
        affection: 10,
        currentLibidoOther: 10,
        baseLibidoOther: 25,
        currentAggressionOther: 40,
        baseAggressionOther: 25,
      );

      final presentation = EmotionPresentationService.summarize(state);

      expect(presentation.relationshipStage, '陌生');
      expect(presentation.trend, '正在降温');
      expect(presentation.trendDescription, contains('拉远'));
    });
  });
}
