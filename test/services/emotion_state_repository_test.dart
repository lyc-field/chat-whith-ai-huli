import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/emotion_state.dart';
import 'package:chat_app/services/emotion_state_repository.dart';

void main() {
  test('copies every legacy emotion field into a persona state', () {
    final legacy = EmotionState(
      id: 'legacy-id',
      conversationId: 'conversation-1',
      affection: 72.5,
      currentLibidoOther: 11.5,
      baseLibidoOther: 21.5,
      currentAggressionOther: 31.5,
      baseAggressionOther: 41.5,
      currentLibidoSelf: 12.5,
      baseLibidoSelf: 22.5,
      currentAggressionSelf: 32.5,
      baseAggressionSelf: 42.5,
      turnCount: 17,
      lastInteraction: DateTime.utc(2026, 1, 2, 3, 4),
      lastUpdate: DateTime.utc(2026, 1, 2, 5, 6),
    );

    final migrated = EmotionStateRepository.copyLegacyToPersona(
      legacy,
      conversationId: 'conversation-1',
      personaId: 'persona-1',
    );

    expect(migrated.id, isNot(legacy.id));
    expect(migrated.conversationId, legacy.conversationId);
    expect(migrated.personaId, 'persona-1');
    expect(migrated.affection, legacy.affection);
    expect(migrated.currentLibidoOther, legacy.currentLibidoOther);
    expect(migrated.baseLibidoOther, legacy.baseLibidoOther);
    expect(migrated.currentAggressionOther, legacy.currentAggressionOther);
    expect(migrated.baseAggressionOther, legacy.baseAggressionOther);
    expect(migrated.currentLibidoSelf, legacy.currentLibidoSelf);
    expect(migrated.baseLibidoSelf, legacy.baseLibidoSelf);
    expect(migrated.currentAggressionSelf, legacy.currentAggressionSelf);
    expect(migrated.baseAggressionSelf, legacy.baseAggressionSelf);
    expect(migrated.turnCount, legacy.turnCount);
    expect(migrated.lastInteraction, legacy.lastInteraction);
    expect(migrated.lastUpdate, legacy.lastUpdate);
  });
}
