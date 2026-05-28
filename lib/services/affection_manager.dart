import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/emotion_state.dart';
import '../models/affection_log.dart';
import '../models/ai_persona.dart';
import 'database_service.dart';
import 'emotion_service.dart';
import 'auth_service.dart';

/// Encapsulates all affection + emotion state management extracted from
/// ChatProvider.  ChatProvider delegates to this class and calls
/// [notifyListeners] after any mutating call.
class AffectionManager {
  static const roundsUntilAffection = 5;

  double affection = 30.0;
  double previousRawAffection = 30.0;
  bool? affectionIncreasing;
  EmotionState? emotionState;
  EmotionAnalyzer? analyzer;
  int roundCount = 0;

  // ─── Computed ────────────────────────────────────────────

  Map<String, String> get emotionLabels => emotionState != null
      ? EmotionTables.getEmotionDescription(emotionState!)
      : {'towards_user': '平淡', 'self_state': '平静'};

  bool get isSelfDestructMode =>
      emotionState != null && EmotionTables.isSelfDestructMode(emotionState!);

  bool get shouldJudgeAffection => roundCount > roundsUntilAffection;

  // ─── Delta parsing (pure, static) ─────────────────────────

  /// Parses the Δ-tag from the end of an AI response.
  /// Returns [cleanContent] (with the tag stripped), [delta] and [reason].
  static ({String cleanContent, double? delta, String? reason}) parseDeltaTag(
      String fullContent) {
    var clean = fullContent;
    var match =
        RegExp(r'Δ\s*([+\-±]?\d+\.?\d*)\s*(.*)').firstMatch(fullContent);
    if (match == null) {
      match = RegExp(r'Δ.{0,30}?([+\-±]?\d+\.?\d*)\s*(.*)$')
          .firstMatch(fullContent);
    }
    if (match != null) {
      final delta = (double.tryParse(match.group(1)!) ?? 0.0).clamp(-0.5, 0.8);
      final reason = match.group(2)!.trim();
      clean = clean.replaceFirst(match.group(0)!, '').trimRight();
      if (clean.isEmpty) clean = fullContent;
      return (cleanContent: clean, delta: delta, reason: reason);
    }
    return (cleanContent: fullContent, delta: null, reason: null);
  }

  // ─── Reset ────────────────────────────────────────────────

  /// Full reset for a brand-new conversation (no DB writes).
  void reset() {
    affection = 30.0;
    previousRawAffection = 30.0;
    affectionIncreasing = null;
    emotionState = null;
    roundCount = 0;
  }

  /// Reset affection + emotion for old-format conversations (writes DB).
  Future<void> resetForOldFormat(String convId) async {
    final initialAffection = (await AuthService.getAdminDefaultAffection()).toDouble();
    affection = initialAffection;
    previousRawAffection = initialAffection;
    affectionIncreasing = null;
    if (emotionState != null) {
      emotionState =
          EmotionState.createDefault(convId, initialAffection: initialAffection);
      await DatabaseService.updateEmotionState(emotionState!);
    }
  }

  /// Reset affection + emotion for new-format (persona) conversations.
  /// Uses the persona's current affection as the initial value (does NOT
  /// overwrite the persona record — the user's configured value is preserved).
  Future<void> resetForNewFormat(String convId, AIPersona persona) async {
    affection = persona.affection;
    previousRawAffection = persona.affection;
    affectionIncreasing = null;
    emotionState = EmotionState.createDefault(convId,
        initialAffection: persona.affection, personaId: persona.id);
    await DatabaseService.deletePersonaEmotionState(convId, persona.id);
    await DatabaseService.insertPersonaEmotionState(emotionState!);
  }

  // ─── Persona sync ────────────────────────────────────────

  /// Load (or create) persona-level emotion state and sync affection.
  Future<void> syncWithPersona(String convId, AIPersona persona) async {
    affection = persona.affection;
    previousRawAffection = persona.affection;
    emotionState =
        await DatabaseService.getPersonaEmotionState(convId, persona.id);
    if (emotionState == null) {
      emotionState = EmotionState.createDefault(convId,
          initialAffection: persona.affection, personaId: persona.id);
      await DatabaseService.insertPersonaEmotionState(emotionState!);
    }
  }

  /// Write current affection back to the persona record + emotion state.
  Future<void> flushToPersona(AIPersona persona) async {
    persona.affection = affection;
    await DatabaseService.updateAIPersona(persona);
    if (emotionState != null) {
      await DatabaseService.updatePersonaEmotionState(emotionState!);
    }
  }

  // ─── Old-format decay on load ────────────────────────────

  /// Apply time-based decay to emotion values (old-format conversations).
  /// Call once when loading a conversation.
  void applyDecayOnLoad() {
    if (emotionState == null) return;
    final now = DateTime.now();
    final elapsed =
        now.difference(emotionState!.lastUpdate).inSeconds / 3600.0;
    if (elapsed <= 0) return;

    emotionState!.currentLibidoOther = DecayCalculator.applyDecay(
        emotionState!.currentLibidoOther,
        emotionState!.baseLibidoOther,
        elapsed,
        2.0);
    emotionState!.currentAggressionOther = DecayCalculator.applyDecay(
        emotionState!.currentAggressionOther,
        emotionState!.baseAggressionOther,
        elapsed,
        2.0);
    emotionState!.currentLibidoSelf = DecayCalculator.applyDecay(
        emotionState!.currentLibidoSelf,
        emotionState!.baseLibidoSelf,
        elapsed,
        2.0);
    emotionState!.currentAggressionSelf = DecayCalculator.applyDecay(
        emotionState!.currentAggressionSelf,
        emotionState!.baseAggressionSelf,
        elapsed,
        2.0);
    emotionState!.lastUpdate = now;
    emotionState!.lastInteraction = now;
  }

  // ─── UI helpers ──────────────────────────────────────────

  void setInitialAffection(int value) {
    affection = value.clamp(15, 50).toDouble();
    previousRawAffection = affection;
    if (emotionState != null) {
      emotionState!.affection = affection;
    }
  }

  /// Returns true when the display affection just crossed an integer boundary.
  /// Called by the UI to trigger the blink animation.
  bool consumeAffectionChanged() {
    final raw = emotionState?.affection ?? affection;
    if ((raw.round() - previousRawAffection.round()).abs() >= 1) {
      affectionIncreasing = raw > previousRawAffection;
      previousRawAffection = raw;
      return true;
    }
    affectionIncreasing = null;
    return false;
  }

  // ─── Apply affection delta ───────────────────────────────

  /// Apply an inline Δ value and persist the affection log row.
  Future<void> applyDelta({
    required double delta,
    required String reason,
    required String convId,
    String? personaId,
    required String userMessage,
    required String aiMessage,
  }) async {
    affection = (affection + delta).clamp(-15.0, 100.0);
    if (emotionState != null) {
      emotionState!.affection = affection;
    }
    await DatabaseService.insertAffectionLog(AffectionLog(
      id: const Uuid().v4(),
      conversationId: convId,
      personaId: personaId,
      delta: delta,
      reason: reason,
      createdAt: DateTime.now(),
      userMessage: userMessage,
      aiMessage: aiMessage,
    ));
  }

  // ─── Unconscious emotion analysis ────────────────────────

  /// Run the full unconscious emotion-analysis round.
  /// [history] is a pre-built string joining all non-empty messages.
  Future<void> analyzeEmotion({
    required String userMessage,
    required String lastAiMessage,
    required String history,
    required String convId,
    String? personaId,
    double sensitivity = 1.0,
    bool isNewFormat = false,
    AIPersona? persona,
  }) async {
    if (analyzer == null || emotionState == null) return;

    try {
      final deltas = await analyzer!.analyzeAndAdjust(
        state: emotionState!,
        history: history,
        latestMsg: userMessage,
      );

      // Apply sensitivity multiplier to all deltas
      final lo =
          ((deltas['libido_other_delta'] as double) * sensitivity).clamp(-2.0, 2.0);
      final ao = ((deltas['aggression_other_delta'] as double) * sensitivity)
          .clamp(-2.0, 2.0);
      final ls =
          ((deltas['libido_self_delta'] as double) * sensitivity).clamp(-2.0, 2.0);
      final as_ = ((deltas['aggression_self_delta'] as double) * sensitivity)
          .clamp(-2.0, 2.0);

      emotionState!.currentLibidoOther =
          (emotionState!.currentLibidoOther + lo).clamp(0.0, 50.0);
      emotionState!.currentAggressionOther =
          (emotionState!.currentAggressionOther + ao).clamp(0.0, 50.0);
      emotionState!.currentLibidoSelf =
          (emotionState!.currentLibidoSelf + ls).clamp(0.0, 50.0);
      emotionState!.currentAggressionSelf =
          (emotionState!.currentAggressionSelf + as_).clamp(0.0, 50.0);

      emotionState!.baseLibidoOther = (emotionState!.baseLibidoOther +
              (deltas['base_libido_other_delta'] as double) * sensitivity)
          .clamp(0.0, 50.0);
      emotionState!.baseAggressionOther = (emotionState!.baseAggressionOther +
              (deltas['base_aggression_other_delta'] as double) * sensitivity)
          .clamp(0.0, 50.0);
      emotionState!.baseLibidoSelf = (emotionState!.baseLibidoSelf +
              (deltas['base_libido_self_delta'] as double) * sensitivity)
          .clamp(0.0, 50.0);
      emotionState!.baseAggressionSelf = (emotionState!.baseAggressionSelf +
              (deltas['base_aggression_self_delta'] as double) * sensitivity)
          .clamp(0.0, 50.0);

      emotionState!.turnCount++;
      emotionState!.lastUpdate = DateTime.now();
      emotionState!.lastInteraction = DateTime.now();

      await DatabaseService.updateEmotionState(emotionState!);

      await DatabaseService.insertEmotionLog(EmotionLog(
        id: const Uuid().v4(),
        conversationId: convId,
        personaId: personaId,
        libidoOtherDelta: lo,
        aggressionOtherDelta: ao,
        libidoSelfDelta: ls,
        aggressionSelfDelta: as_,
        intensity: (deltas['intensity'] as double),
        userMessage: userMessage,
        aiMessage: lastAiMessage,
      ));

      // Flush persona affection for new format
      if (isNewFormat && persona != null) {
        await flushToPersona(persona);
      }
    } catch (e) {
      debugPrint('[AffectionManager] 潜意识分析失败，下轮重试: $e');
    }
  }
}
