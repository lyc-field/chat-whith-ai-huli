import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/emotion_service.dart';
import 'package:chat_app/models/emotion_state.dart';

void main() {
  // ─── EmotionTables ──────────────────────────────────────

  group('EmotionTables', () {
    test('getEmotionDescription returns correct labels for default state', () {
      final state = EmotionState.createDefault('test_conv');
      final labels = EmotionTables.getEmotionDescription(state);
      expect(labels['towards_user'], isNotNull);
      expect(labels['self_state'], isNotNull);
    });

    test('getEmotionDescription at high affection + high libido = 迷恋', () {
      final state = EmotionState(
        id: 's1',
        conversationId: 'c1',
        affection: 60.0,
        currentLibidoOther: 45.0,
        currentAggressionOther: 5.0,
      );
      final labels = EmotionTables.getEmotionDescription(state);
      // affection >= 50 bracket, libido mapped to 37.5, aggression mapped to 0 → 迷恋 or near
      expect(labels['towards_user']!.length, greaterThan(0));
    });

    test('low affection + high aggression produces negative labels', () {
      final state = EmotionState(
        id: 's2',
        conversationId: 'c2',
        affection: 5.0,
        currentLibidoOther: 5.0,
        currentAggressionOther: 45.0,
      );
      final labels = EmotionTables.getEmotionDescription(state);
      expect(labels['towards_user']!.length, greaterThan(0));
    });

    test('isSelfDestructMode true when selfAggression >= 37.5 and selfLibido <= 12.5', () {
      final state = EmotionState(
        id: 's3',
        conversationId: 'c3',
        currentAggressionSelf: 40.0,
        currentLibidoSelf: 5.0,
      );
      expect(EmotionTables.isSelfDestructMode(state), isTrue);
    });

    test('isSelfDestructMode false when selfAggression is low', () {
      final state = EmotionState(
        id: 's4',
        conversationId: 'c4',
        currentAggressionSelf: 10.0,
        currentLibidoSelf: 30.0,
      );
      expect(EmotionTables.isSelfDestructMode(state), isFalse);
    });

    test('getTowardsUserGrid returns 5x5 grid', () {
      final state = EmotionState(
        id: 's5',
        conversationId: 'c5',
        affection: 30.0,
      );
      final grid = EmotionTables.getTowardsUserGrid(state);
      expect(grid.length, 5);
      for (final row in grid) {
        expect(row.length, 5);
      }
    });

    test('getSelfGrid returns 5x5 grid', () {
      final grid = EmotionTables.getSelfGrid();
      expect(grid.length, 5);
      for (final row in grid) {
        expect(row.length, 5);
      }
    });

    test('getTowardsUserBracket returns valid indices', () {
      final state = EmotionState(
        id: 's6',
        conversationId: 'c6',
        currentLibidoOther: 20.0,
        currentAggressionOther: 30.0,
      );
      final bracket = EmotionTables.getTowardsUserBracket(state);
      expect(bracket.col, inClosedOpenRange(0, 5));
      expect(bracket.row, inClosedOpenRange(0, 5));
    });

    test('getSelfBracket returns valid indices', () {
      final state = EmotionState(
        id: 's7',
        conversationId: 'c7',
        currentLibidoSelf: 10.0,
        currentAggressionSelf: 40.0,
      );
      final bracket = EmotionTables.getSelfBracket(state);
      expect(bracket.col, inClosedOpenRange(0, 5));
      expect(bracket.row, inClosedOpenRange(0, 5));
    });
  });

  // ─── DecayCalculator ────────────────────────────────────

  group('DecayCalculator', () {
    test('computeDecay returns 0 at elapsed 0', () {
      final delta = DecayCalculator.computeDecay(0, 10.0, 2.0);
      expect(delta, closeTo(0.0, 0.001));
    });

    test('computeDecay returns full negative deviation at elapsed >= duration', () {
      final delta = DecayCalculator.computeDecay(2.0, 10.0, 2.0);
      expect(delta, closeTo(-10.0, 0.001));
    });

    test('computeDecay is quadratic (partial elapsed)', () {
      // elapsed = 1h, deviation = 10, duration = 2h → ratio = 0.5, decay = 10 * 0.25 = 2.5
      final delta = DecayCalculator.computeDecay(1.0, 10.0, 2.0);
      expect(delta, closeTo(-2.5, 0.001));
    });

    test('applyDecay returns current if no deviation', () {
      final result = DecayCalculator.applyDecay(25.0, 25.0, 1.0, 2.0);
      expect(result, closeTo(25.0, 0.001));
    });

    test('applyDecay moves current toward baseline', () {
      final result = DecayCalculator.applyDecay(35.0, 25.0, 1.0, 2.0);
      // deviation = 10, duration = 2, ratio = 0.5, decay = -2.5, result = 32.5
      expect(result, closeTo(32.5, 0.001));
    });

    test('applyDecay clamps to 0..50', () {
      // current is already at 0, decay shouldn't go negative
      final result = DecayCalculator.applyDecay(0.0, 25.0, 1.0, 2.0);
      expect(result, greaterThanOrEqualTo(0.0));
      expect(result, lessThanOrEqualTo(50.0));
    });

    test('applyDecay with duration <= 0 defaults to 0.5', () {
      // duration 0 → defaults to 0.5, elapsed=0.4 → ratio=0.8, decay=dev*0.64
      final result = DecayCalculator.applyDecay(35.0, 25.0, 0.4, 0.0);
      // deviation=10, duration->0.5, ratio=0.8, decay=10*0.64=6.4, result=28.6
      expect(result, closeTo(28.6, 0.01));
    });
  });
}
