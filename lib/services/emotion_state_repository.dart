import 'package:uuid/uuid.dart';
import '../models/ai_persona.dart';
import '../models/emotion_state.dart';
import 'database_service.dart';

/// Single access point for conversation/persona emotion state.
///
/// Legacy conversation-scoped rows remain readable for backwards
/// compatibility. When a persona is present, the legacy state is copied into
/// a persona-scoped row on first access and the legacy row is retained.
class EmotionStateRepository {
  const EmotionStateRepository._();

  static EmotionState copyLegacyToPersona(
    EmotionState legacy, {
    required String conversationId,
    required String personaId,
  }) {
    return EmotionState(
      id: const Uuid().v4(),
      conversationId: conversationId,
      personaId: personaId,
      affection: legacy.affection,
      currentLibidoOther: legacy.currentLibidoOther,
      baseLibidoOther: legacy.baseLibidoOther,
      currentAggressionOther: legacy.currentAggressionOther,
      baseAggressionOther: legacy.baseAggressionOther,
      currentLibidoSelf: legacy.currentLibidoSelf,
      baseLibidoSelf: legacy.baseLibidoSelf,
      currentAggressionSelf: legacy.currentAggressionSelf,
      baseAggressionSelf: legacy.baseAggressionSelf,
      turnCount: legacy.turnCount,
      lastInteraction: legacy.lastInteraction,
      lastUpdate: legacy.lastUpdate,
    );
  }

  static Future<EmotionState?> loadForConversation(String conversationId) {
    return DatabaseService.getEmotionState(conversationId);
  }

  static Future<EmotionState?> loadForPersona(
    String conversationId,
    String personaId,
  ) {
    return DatabaseService.getPersonaEmotionState(conversationId, personaId);
  }

  static Future<EmotionState> ensureForPersona(
    String conversationId,
    AIPersona persona,
  ) async {
    final existing = await loadForPersona(conversationId, persona.id);
    if (existing != null) return existing;

    final legacy = await loadForConversation(conversationId);
    final state = legacy == null
        ? EmotionState.createDefault(
            conversationId,
            initialAffection: persona.affection,
            personaId: persona.id,
          )
        : copyLegacyToPersona(
            legacy,
            conversationId: conversationId,
            personaId: persona.id,
          );
    await DatabaseService.insertPersonaEmotionState(state);
    return state;
  }

  static Future<EmotionState> ensureForConversation(
    String conversationId, {
    double initialAffection = 30.0,
  }) async {
    final existing = await loadForConversation(conversationId);
    if (existing != null) return existing;

    final state = EmotionState.createDefault(
      conversationId,
      initialAffection: initialAffection,
    );
    await DatabaseService.insertEmotionState(state);
    return state;
  }

  static Future<void> save(EmotionState state) async {
    if (state.personaId != null && state.personaId!.isNotEmpty) {
      await DatabaseService.updatePersonaEmotionState(state);
      return;
    }
    await DatabaseService.updateEmotionState(state);
  }

  static Future<void> insert(EmotionState state) async {
    if (state.personaId != null && state.personaId!.isNotEmpty) {
      await DatabaseService.insertPersonaEmotionState(state);
      return;
    }
    await DatabaseService.insertEmotionState(state);
  }

  static Future<void> deleteForConversation(String conversationId) async {
    await DatabaseService.deleteEmotionState(conversationId);
    await DatabaseService.deletePersonaEmotionStates(conversationId);
  }
}
