import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/affection_manager.dart';
import 'package:chat_app/models/emotion_state.dart';

void main() {
  group('AffectionManager.parseDeltaTag', () {
    test('parses positive delta correctly', () {
      final result = AffectionManager.parseDeltaTag(
        'Some response text Δ+0.3 用户的关心让我感到温暖',
      );
      expect(result.cleanContent, 'Some response text');
      expect(result.delta, closeTo(0.3, 0.001));
      expect(result.reason, '用户的关心让我感到温暖');
    });

    test('parses negative delta correctly', () {
      final result = AffectionManager.parseDeltaTag(
        'I am upset Δ-0.2 用户说了伤人的话',
      );
      expect(result.cleanContent, 'I am upset');
      expect(result.delta, closeTo(-0.2, 0.001));
      expect(result.reason, '用户说了伤人的话');
    });

    test('parses delta with ± prefix', () {
      final result = AffectionManager.parseDeltaTag(
        'Neutral response Δ±0.0 没有特别的感觉',
      );
      expect(result.delta, closeTo(0.0, 0.001));
    });

    test('returns null delta when no Δ tag present', () {
      final result = AffectionManager.parseDeltaTag(
        'This is a normal response without any delta tag.',
      );
      expect(result.cleanContent, 'This is a normal response without any delta tag.');
      expect(result.delta, isNull);
      expect(result.reason, isNull);
    });

    test('strips only the Δ tag portion from the end', () {
      final result = AffectionManager.parseDeltaTag(
        '前面有Δ字符但不是标签的部分，真标签在这里 Δ+0.5 好感动',
      );
      expect(result.cleanContent, contains('前面有Δ字符但不是标签的部分'));
      expect(result.delta, closeTo(0.5, 0.001));
    });

    test('handles delta tag with text between Δ and number (fallback)', () {
      final result = AffectionManager.parseDeltaTag(
        '一些回复 Δ（感动）+0.3 原因说明',
      );
      // The first regex might not match, but the fallback regex should
      // The first regex requires Δ\s*[+\-±]?\d+, so "Δ（感动）+0.3" won't match the first
      // The fallback: Δ.{0,30}?([+\-±]?\d+\.?\d*)\s*(.*)$ should match
      expect(result.delta, isNotNull);
    });

    test('preserves content when Δ tag is at the very end', () {
      final result = AffectionManager.parseDeltaTag(
        'Short reply Δ+0.1',
      );
      // cleanContent would become empty after stripping, but we keep the original
      expect(result.cleanContent, isNotEmpty);
      expect(result.delta, closeTo(0.1, 0.001));
    });

    test('correctly strips extra whitespace around Δ tag', () {
      final result = AffectionManager.parseDeltaTag(
        'Nice reply.  Δ-0.1   mild disappointment  ',
      );
      expect(result.cleanContent, 'Nice reply.');
      expect(result.delta, closeTo(-0.1, 0.001));
      expect(result.reason, 'mild disappointment');
    });
  });

  group('AffectionManager state', () {
    test('default values are correct', () {
      final mgr = AffectionManager();
      expect(mgr.affection, 30.0);
      expect(mgr.previousRawAffection, 30.0);
      expect(mgr.roundCount, 0);
      expect(mgr.emotionState, isNull);
      expect(mgr.analyzer, isNull);
      expect(mgr.affectionIncreasing, isNull);
    });

    test('reset restores defaults', () {
      final mgr = AffectionManager()
        ..affection = 80.0
        ..roundCount = 10
        ..affectionIncreasing = true;

      mgr.reset();

      expect(mgr.affection, 30.0);
      expect(mgr.previousRawAffection, 30.0);
      expect(mgr.roundCount, 0);
      expect(mgr.affectionIncreasing, isNull);
      expect(mgr.emotionState, isNull);
    });

    test('shouldJudgeAffection false before threshold', () {
      final mgr = AffectionManager()..roundCount = 3;
      expect(mgr.shouldJudgeAffection, isFalse);
    });

    test('shouldJudgeAffection true after threshold', () {
      final mgr = AffectionManager()..roundCount = 6;
      expect(mgr.shouldJudgeAffection, isTrue);
    });

    test('emotionLabels returns defaults when emotionState is null', () {
      final mgr = AffectionManager();
      expect(mgr.emotionLabels, {'towards_user': '平淡', 'self_state': '平静'});
    });

    test('isSelfDestructMode false when emotionState is null', () {
      final mgr = AffectionManager();
      expect(mgr.isSelfDestructMode, isFalse);
    });

    test('consumeAffectionChanged detects integer crossing', () {
      final mgr = AffectionManager()
        ..affection = 30.5
        ..previousRawAffection = 30.0;

      expect(mgr.consumeAffectionChanged(), isTrue);
      expect(mgr.affectionIncreasing, isTrue);
    });

    test('consumeAffectionChanged returns false when no crossing', () {
      final mgr = AffectionManager()
        ..affection = 30.4
        ..previousRawAffection = 30.0;

      expect(mgr.consumeAffectionChanged(), isFalse);
      expect(mgr.affectionIncreasing, isNull);
    });

    test('setInitialAffection clamps to 15..50', () {
      final mgr = AffectionManager();

      mgr.setInitialAffection(5);
      expect(mgr.affection, 15.0);

      mgr.setInitialAffection(80);
      expect(mgr.affection, 50.0);

      mgr.setInitialAffection(30);
      expect(mgr.affection, 30.0);
    });

    test('setInitialAffection syncs to emotionState', () {
      final mgr = AffectionManager();
      mgr.emotionState = EmotionState(
        id: 'e1',
        conversationId: 'c1',
      );
      mgr.setInitialAffection(40);
      expect(mgr.emotionState!.affection, 40.0);
    });
  });
}
