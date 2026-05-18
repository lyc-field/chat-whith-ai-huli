import '../models/message.dart';
import '../models/segment_summary.dart';
import '../models/emotion_state.dart';
import '../services/auth_service.dart';
import '../services/emotion_service.dart';
import '../services/database_service.dart';

/// Builds the full message context for AI API calls.
/// Extracted from ChatProvider to eliminate duplication between
/// sendMessage() and sendContinueCommand().
class ContextBuilder {
  /// Maximum active (non-archived, non-empty) messages to include.
  static const maxActiveMessages = 40;

  /// Build context messages for a normal send (with optional Δ tag injection).
  /// Returns the context list. Modifies the last user message in-place
  /// to append the Δ tag instruction when applicable.
  static Future<List<Map<String, dynamic>>> build({
    required String conversationId,
    required String? systemPrompt,
    required String? conversationPrompt,
    required String? userPersona,
    required String? worldBackground,
    required EmotionState? emotionState,
    required bool affectionEnabled,
    required String mode,
    required List<Message> messages,
    required List<SegmentSummary> segments,
    bool injectDeltaTag = false,
    bool injectContinue = false,
  }) async {
    final contextMsgs = <Map<String, dynamic>>[];

    // 1. System prompt with emotion panel + global rules
    final sPrompt = systemPrompt ?? conversationPrompt;
    final globalPrompt = await AuthService.getGlobalPrompt();
    final hasGlobal = globalPrompt != null && globalPrompt.trim().isNotEmpty;
    final hasUser = sPrompt != null && sPrompt.trim().isNotEmpty;

    if (hasUser || hasGlobal || (affectionEnabled && emotionState != null)) {
      final sb = StringBuffer();
      if (hasUser) {
        sb.writeln(sPrompt.trim());
      }
      if (userPersona != null && userPersona.trim().isNotEmpty) {
        sb.writeln();
        sb.writeln('【你正在对话的对象（用户）】');
        sb.writeln(userPersona.trim());
      }
      if (worldBackground != null && worldBackground.trim().isNotEmpty) {
        sb.writeln();
        sb.writeln('【世界背景】');
        sb.writeln(worldBackground.trim());
      }
      if (affectionEnabled && emotionState != null) {
        _appendEmotionPanel(sb, emotionState);
      }
      if ((hasUser || (affectionEnabled && emotionState != null)) &&
          hasGlobal) {
        sb.writeln();
        sb.writeln('---');
        sb.writeln();
      }
      if (hasGlobal) {
        sb.writeln('[不可违背的安全规则]');
        sb.writeln(globalPrompt.trim());
      }
      contextMsgs.add({'role': 'system', 'content': sb.toString()});
    }

    // 2. Segment summaries
    for (final seg in segments) {
      if (seg.content.trim().isNotEmpty) {
        contextMsgs.add({
          'role': 'system',
          'content': '[对话历史总结 ${seg.segmentIndex + 1}] ${seg.content}',
        });
      }
    }

    // 3. Active (non-archived, non-empty) messages
    final active = messages
        .where((m) => m.content.isNotEmpty && m.segmentIndex == null)
        .toList();
    final recent = active.length > maxActiveMessages
        ? active.sublist(active.length - maxActiveMessages)
        : active;

    // 4. Bookmarked messages (bookmark mode only)
    if (mode == 'bookmark') {
      final bookmarkMsgs =
          await DatabaseService.getBookmarkedMessages(conversationId);
      final recentIds = recent.map((m) => m.id).toSet();
      for (final bm in bookmarkMsgs) {
        if (!recentIds.contains(bm.id)) {
          final who = bm.role == 'user' ? '用户曾说过' : '你曾回复';
          contextMsgs.add({
            'role': 'system',
            'content': '[书签记忆 — $who] ${bm.content}',
          });
        }
      }
    }

    // 5. Recent messages
    for (final m in recent) {
      contextMsgs.add({'role': m.role, 'content': m.content});
    }

    // 6. Optional injections
    if (injectDeltaTag) {
      _injectDeltaInstruction(contextMsgs);
    }
    if (injectContinue) {
      contextMsgs.add({
        'role': 'system',
        'content': '（用户没有回复，请角色继续推进剧情，自然地往下说，不要重复上一句的内容）',
      });
    }

    return contextMsgs;
  }

  static void _appendEmotionPanel(StringBuffer sb, EmotionState state) {
    final labels = EmotionTables.getEmotionDescription(state);
    sb.writeln();
    sb.writeln('【当前情绪数值】');
    sb.writeln(
        '他力比多：${state.currentLibidoOther.toStringAsFixed(1)}/50（亲近/给予温暖的欲望）');
    sb.writeln(
        '他攻击性：${state.currentAggressionOther.toStringAsFixed(1)}/50（推开/伤害的冲动）');
    sb.writeln('好感度：${state.affection.toStringAsFixed(1)}/100');
    sb.writeln(
        '自力比多：${state.currentLibidoSelf.toStringAsFixed(1)}/50（自爱/珍视自己）');
    sb.writeln(
        '自攻击性：${state.currentAggressionSelf.toStringAsFixed(1)}/50（自责/自我毁灭）');
    sb.writeln(
        '参考标签：对用户「${labels['towards_user']}」，自身「${labels['self_state']}」');
    if (EmotionTables.isSelfDestructMode(state)) {
      sb.writeln('⚠ 当前处于自毁倾诉模式：话量激增、自我贬低、难以自控');
    }
    sb.writeln('（请根据上述数值和你在人设中定义的情绪驱动规则来演绎角色，不要提及数值。）');
  }

  /// Inject the Δ tag instruction into the last user message in contextMsgs.
  static void _injectDeltaInstruction(List<Map<String, dynamic>> contextMsgs) {
    for (int i = contextMsgs.length - 1; i >= 0; i--) {
      if (contextMsgs[i]['role'] == 'user') {
        contextMsgs[i]['content'] =
            '${contextMsgs[i]['content']}\n\n[回复末尾附加好感度标记：Δ±数字 原因（范围-0.5~+0.8，示例：Δ+0.3 用户的关心让我感到温暖，必须执行）]';
        break;
      }
    }
  }
}
