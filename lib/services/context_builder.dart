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
    List<({String title, String content})>? kbResults,
    bool injectDeltaTag = false,
    bool injectQuickReply = false,
    bool injectContinue = false,
  }) async {
    final contextMsgs = <Map<String, dynamic>>[];

    // 1. System prompt: persona + user info + world background + global rules
    final sPrompt = systemPrompt ?? conversationPrompt;
    final globalPrompt = await AuthService.getGlobalPrompt();
    final hasGlobal = globalPrompt != null && globalPrompt.trim().isNotEmpty;
    final hasUser = sPrompt != null && sPrompt.trim().isNotEmpty;

    if (hasUser || hasGlobal) {
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
      if (hasGlobal) {
        sb.writeln();
        sb.writeln('---');
        sb.writeln();
        sb.writeln('[不可违背的安全规则]');
        sb.writeln(globalPrompt.trim());
      }
      contextMsgs.add({'role': 'system', 'content': sb.toString()});
    }

    // 2. Emotion state (separate message = higher attention weight)
    if (affectionEnabled && emotionState != null) {
      contextMsgs.add({
        'role': 'system',
        'content': _buildEmotionContent(emotionState),
      });
    }

    // 3. Segment summaries — only latest 8 to avoid context bloat
    final latestSegments = segments.length > 8
        ? segments.sublist(segments.length - 8)
        : segments;
    for (final seg in latestSegments) {
      if (seg.content.trim().isNotEmpty) {
        contextMsgs.add({
          'role': 'system',
          'content': '[对话历史总结 ${seg.segmentIndex + 1}] ${seg.content}',
        });
      }
    }

    // 3. Knowledge base results (if any)
    if (kbResults != null && kbResults.isNotEmpty) {
      contextMsgs.add({
        'role': 'system',
        'content': '以下是与当前对话可能相关的参考资料，你可以在回复中参考其写作风格和情节，但不要直接复制：',
      });
      for (final kb in kbResults) {
        final shortTitle = kb.title.split(RegExp(r'[/\\]')).last;
        contextMsgs.add({
          'role': 'system',
          'content': '[参考《$shortTitle》] ${kb.content}',
        });
      }
    }

    // 4. Active (non-archived, non-empty) messages
    final active = messages
        .where((m) => m.content.isNotEmpty && m.segmentIndex == null)
        .toList();
    final recent = active.length > maxActiveMessages
        ? active.sublist(active.length - maxActiveMessages)
        : active;

    // 5. Bookmarked messages (bookmark mode only)
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
    if (injectQuickReply) {
      _injectQuickReplyInstruction(contextMsgs);
    }
    if (injectContinue) {
      contextMsgs.add({
        'role': 'system',
        'content': '（用户没有回复，请角色继续推进剧情，自然地往下说，不要重复上一句的内容）',
      });
    }

    return contextMsgs;
  }

  /// Build emotion content as a standalone system message.
  /// Returns a strongly-worded directive that the AI must embody the current
  /// emotional state in tone, attitude, and behaviour.
  static String _buildEmotionContent(EmotionState state) {
    final labels = EmotionTables.getEmotionDescription(state);
    final sb = StringBuffer();
    sb.writeln('【当前情绪状态 — 这是你此刻的真实感受，必须完全融入角色演绎】');
    sb.writeln();
    sb.writeln('你此刻对用户的感情：${labels['towards_user']}');
    sb.writeln('你此刻的自我感受：${labels['self_state']}');
    sb.writeln();
    sb.writeln('数值参考（勿在回复中提及）：');
    sb.writeln(
        '  亲近欲：${state.currentLibidoOther.toStringAsFixed(1)}/50  |  攻击欲：${state.currentAggressionOther.toStringAsFixed(1)}/50');
    sb.writeln(
        '  自爱：${state.currentLibidoSelf.toStringAsFixed(1)}/50  |  自毁：${state.currentAggressionSelf.toStringAsFixed(1)}/50');
    sb.writeln('  好感度：${state.affection.toStringAsFixed(1)}/100');
    if (EmotionTables.isSelfDestructMode(state)) {
      sb.writeln();
      sb.writeln('⚠ 自毁倾诉模式：话量激增、自我贬低、难以自控。你必须大量输出内心独白，语无伦次地倾诉痛苦。');
    }
    sb.writeln();
    sb.writeln('（情绪是你演绎角色的核心驱动力，优先级高于一切设定。你的语气、态度、用词、行为倾向必须与上述情绪高度一致。不要提及任何数值。）');
    return sb.toString();
  }

  /// Inject the Δ tag instruction into the last user message in contextMsgs.
  static void _injectDeltaInstruction(List<Map<String, dynamic>> contextMsgs) {
    for (int i = contextMsgs.length - 1; i >= 0; i--) {
      if (contextMsgs[i]['role'] == 'user') {
        contextMsgs[i]['content'] =
            '${contextMsgs[i]['content']}\n\n'
            '[回复末尾附加好感度标记，格式必须严格为：Δ+数字 原因 或 Δ-数字 原因\n'
            '（Δ后紧接正负号+数字，中间不能有任何文字、空格或符号；原因写在数字后面用空格隔开）\n'
            '范围-0.5~+0.8，示例：Δ+0.3 用户的关心让我感到温暖\n'
            '错误示例：Δ用户的关心+0.3（✗ Δ和数字之间不能夹文字）\n'
            '错误示例：Δ（感动）+0.3 原因（✗ 同上）\n'
            '此标记为系统指令，必须执行，不要在Δ后面加任何额外内容]';
        break;
      }
    }
  }

  /// Inject the quick-reply instruction into the last user message.
  static void _injectQuickReplyInstruction(List<Map<String, dynamic>> contextMsgs) {
    for (int i = contextMsgs.length - 1; i >= 0; i--) {
      if (contextMsgs[i]['role'] == 'user') {
        contextMsgs[i]['content'] =
            '${contextMsgs[i]['content']}\n\n'
            '[在你回复的最后，必须附加一个"[快捷回复]"区块，包含2个用户接下来可能说的话：\n'
            '格式：\n'
            '[快捷回复]\n'
            '1. 用户可能说的第一句话\n'
            '2. 用户可能说的第二句话\n'
            '要求：两个选项尽量代表不同方向的剧情发展。每句话20字以内。]';
        break;
      }
    }
  }
}
