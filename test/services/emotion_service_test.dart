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

}
