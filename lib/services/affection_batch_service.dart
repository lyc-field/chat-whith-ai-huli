import 'dart:math' as math;

import 'json_utils.dart';

class AffectionRound {
  final String user;
  final String assistant;

  const AffectionRound({
    required this.user,
    required this.assistant,
  });
}

class AffectionJudgement {
  final double delta;
  final String reason;

  const AffectionJudgement({
    required this.delta,
    required this.reason,
  });
}

class EmotionDeltaPolicy {
  EmotionDeltaPolicy._();

  static double currentDeltaCap(double intensity) {
    if (intensity <= 0.5) return 0.0;
    if (intensity < 1.5) return 0.1;
    return 2.0;
  }

  static double scaleCurrentDelta(
      double raw, double intensity, double sensitivity) {
    final cap = currentDeltaCap(intensity);
    if (cap == 0.0) return 0.0;
    final multiplier = sensitivity.clamp(0.1, 1.0);
    return (raw * multiplier).clamp(-cap, cap);
  }

  static double scaleBaseDelta(
      double raw, double intensity, double sensitivity, double cap) {
    if (intensity <= 0.5) return 0.0;
    final multiplier = sensitivity.clamp(0.1, 1.0);
    return (raw * multiplier).clamp(-cap, cap);
  }
}

class AffectionBatchService {
  AffectionBatchService._();

  static String buildSummaryPrompt(List<AffectionRound> rounds) {
    final body = rounds.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final round = entry.value;
      return '第$i轮\n用户：${round.user}\n角色：${round.assistant}';
    }).join('\n\n');
    return '''
请先总结以下四轮虚构角色扮演互动，再用于判断关系变化。
只总结事实、情绪和关系推进，不要评价用户，也不要输出好感度数值。
总结应简洁、连续、完整，控制在80字以内。

$body
''';
  }

  static String buildJudgementPrompt(
      String summary, List<AffectionRound> rounds) {
    final body = rounds.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final round = entry.value;
      return '第$i轮：用户=${round.user}；角色=${round.assistant}';
    }).join('\n');
    return '''
根据“四轮互动总结”和原始四轮内容，统一判断本轮关系好感度变化。
这是虚构角色扮演，不是现实行为判断。

【四轮互动总结】
$summary

【原始四轮内容】
$body

只输出 JSON：
{"affection_delta":0.0,"affection_reason":"15到30字的单行原因"}

affection_delta 范围为 -0.3 到 0.8。
原因必须非空、15到30字、不能换行。
''';
  }

  static AffectionJudgement parseJudgement(String raw) {
    final root = JsonUtils.extractJson(raw) ?? const <String, dynamic>{};
    final rawDelta = (root['affection_delta'] as num?)?.toDouble() ?? 0.0;
    final reason = normalizeReason(root['affection_reason'] as String? ?? '');
    return AffectionJudgement(
      delta: rawDelta.clamp(-0.3, 0.8),
      reason: reason,
    );
  }

  static String normalizeReason(String raw) {
    var reason = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (reason.isEmpty) {
      reason = '这几轮互动让彼此的关系产生了新的变化';
    }
    if (reason.runes.length < 15) {
      reason = '$reason，影响了彼此的互动感受';
    }
    if (reason.runes.length < 15) {
      reason = '这几轮互动让彼此的关系产生了新的变化';
    }
    final runes = reason.runes.toList();
    return String.fromCharCodes(
      runes.take(math.min(30, math.max(15, runes.length))).toList(),
    );
  }
}
