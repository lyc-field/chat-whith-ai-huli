import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/emotion_state.dart';
import '../models/affection_log.dart';
import '../models/ai_persona.dart';
import 'database_service.dart';
import 'emotion_service.dart';
import 'auth_service.dart';
import 'emotion_state_repository.dart';
import 'affection_batch_service.dart';

/// Encapsulates all affection + emotion state management extracted from
/// ChatProvider.  ChatProvider delegates to this class and calls
/// [notifyListeners] after any mutating call.
class AffectionManager {
  static const roundsUntilAffection = 4;
  static const affectionJudgeInterval = 4;
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

  /// Judge relationship change once every four rounds (within the requested
  /// three-to-five-round cadence) instead of on every turn.
  bool get shouldJudgeAffection =>
      roundCount >= roundsUntilAffection &&
      roundCount % affectionJudgeInterval == 0;

  static bool shouldUsePersonaEmotionState({
    required bool isNewFormat,
    required String? personaId,
  }) {
    return isNewFormat && personaId != null && personaId.isNotEmpty;
  }

  // ─── Delta parsing (pure, static) ─────────────────────────

  /// Parses the Δ-tag from the end of an AI response.
  /// Returns [cleanContent] (with the tag stripped), [delta] and [reason].
  static ({String cleanContent, double? delta, String? reason}) parseDeltaTag(
      String fullContent) {
    var clean = fullContent;
    var match =
        RegExp(r'Δ\s*([+\-±]?\d+\.?\d*)\s*(.*)').firstMatch(fullContent);
    match ??= RegExp(r'Δ.{0,30}?([+\-±]?\d+\.?\d*)\s*(.*)$')
        .firstMatch(fullContent);
    if (match != null) {
      final delta = (double.tryParse(match.group(1)!) ?? 0.0).clamp(-0.3, 0.8);
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
    final initialAffection =
        (await AuthService.getAdminDefaultAffection()).toDouble();
    affection = initialAffection;
    previousRawAffection = initialAffection;
    affectionIncreasing = null;
    if (emotionState != null) {
      emotionState = EmotionState.createDefault(convId,
          initialAffection: initialAffection);
      await EmotionStateRepository.insert(emotionState!);
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
    await EmotionStateRepository.insert(emotionState!);
  }

  // ─── Persona sync ────────────────────────────────────────

  /// Load (or create) persona-level emotion state and sync affection.
  Future<void> syncWithPersona(String convId, AIPersona persona) async {
    affection = persona.affection;
    previousRawAffection = persona.affection;
    emotionState =
        await EmotionStateRepository.ensureForPersona(convId, persona);
    emotionState!.affection = persona.affection;
  }

  /// Write current affection back to the persona record + emotion state.
  Future<void> flushToPersona(AIPersona persona) async {
    persona.affection = affection;
    await DatabaseService.updateAIPersona(persona);
    if (emotionState != null) {
      await EmotionStateRepository.save(emotionState!);
    }
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
    AIPersona? persona,
    bool Function()? isRequestCurrent,
  }) async {
    if (isRequestCurrent != null && !isRequestCurrent()) return;
    final targetState = emotionState;
    final normalizedReason =
        AffectionBatchService.normalizeReason(reason);
    affection = (affection + delta).clamp(-15.0, 100.0);
    if (targetState != null) {
      targetState.affection = affection;
    }
    final targetPersona = persona;
    if (targetState == null) return;
    if (targetPersona != null) {
      targetPersona.affection = affection;
    }
    await DatabaseService.persistAffectionDelta(
      state: targetState,
      persona: targetPersona,
      log: AffectionLog(
        id: const Uuid().v4(),
        conversationId: convId,
        personaId: personaId,
        delta: delta,
        reason: normalizedReason,
        createdAt: DateTime.now(),
        userMessage: userMessage,
        aiMessage: aiMessage,
      ),
    );
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
    bool Function()? isRequestCurrent,
  }) async {
    if (analyzer == null || emotionState == null) return;

    final state = emotionState!;

    try {
      final deltas = await analyzer!.analyzeAndAdjust(
        state: state,
        history: history,
        latestMsg: userMessage,
      );
      if (isRequestCurrent != null && !isRequestCurrent()) return;

      // Apply sensitivity multiplier to all deltas
      final intensity = deltas['intensity'] as double;
      final lo = EmotionDeltaPolicy.scaleCurrentDelta(
          deltas['libido_other_delta'] as double, intensity, sensitivity);
      final ao = EmotionDeltaPolicy.scaleCurrentDelta(
          deltas['aggression_other_delta'] as double, intensity, sensitivity);
      final ls = EmotionDeltaPolicy.scaleCurrentDelta(
          deltas['libido_self_delta'] as double, intensity, sensitivity);
      final as_ = EmotionDeltaPolicy.scaleCurrentDelta(
          deltas['aggression_self_delta'] as double, intensity, sensitivity);

      state.currentLibidoOther =
          (state.currentLibidoOther + lo).clamp(0.0, 50.0);
      state.currentAggressionOther =
          (state.currentAggressionOther + ao).clamp(0.0, 50.0);
      state.currentLibidoSelf = (state.currentLibidoSelf + ls).clamp(0.0, 50.0);
      state.currentAggressionSelf =
          (state.currentAggressionSelf + as_).clamp(0.0, 50.0);

      state.baseLibidoOther = (state.baseLibidoOther +
              EmotionDeltaPolicy.scaleBaseDelta(
                  deltas['base_libido_other_delta'] as double,
                  intensity,
                  sensitivity,
                  state.turnCount <= 10 ? 1.5 : 0.2))
          .clamp(0.0, 50.0);
      state.baseAggressionOther = (state.baseAggressionOther +
              EmotionDeltaPolicy.scaleBaseDelta(
                  deltas['base_aggression_other_delta'] as double,
                  intensity,
                  sensitivity,
                  state.turnCount <= 10 ? 1.5 : 0.2))
          .clamp(0.0, 50.0);
      state.baseLibidoSelf = (state.baseLibidoSelf +
              EmotionDeltaPolicy.scaleBaseDelta(
                  deltas['base_libido_self_delta'] as double,
                  intensity,
                  sensitivity,
                  0.2))
          .clamp(0.0, 50.0);
      state.baseAggressionSelf = (state.baseAggressionSelf +
              EmotionDeltaPolicy.scaleBaseDelta(
                  deltas['base_aggression_self_delta'] as double,
                  intensity,
                  sensitivity,
                  0.2))
          .clamp(0.0, 50.0);

      state.turnCount++;
      state.lastUpdate = DateTime.now();
      state.lastInteraction = DateTime.now();

      if (isRequestCurrent != null && !isRequestCurrent()) return;
      await EmotionStateRepository.save(state);
      if (isRequestCurrent != null && !isRequestCurrent()) return;

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
        if (isRequestCurrent != null && !isRequestCurrent()) return;
        persona.affection = state.affection;
        await DatabaseService.updateAIPersona(persona);
      }
    } catch (e) {
      debugPrint('[AffectionManager] 潜意识分析失败，下轮重试: $e');
    }
  }
}
