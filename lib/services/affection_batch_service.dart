import 'dart:math' as math;
import 'json_utils.dart';

class AffectionRound {
  final String user;
  final String assistant;
  const AffectionRound({required this.user, required this.assistant});
}

class AffectionJudgement {
  final double delta;
  final String reason;
  final String detailedReason;
  const AffectionJudgement({
    required this.delta,
    required this.reason,
    this.detailedReason = '',
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
    return (raw * sensitivity.clamp(0.1, 1.0)).clamp(-cap, cap);
  }

  static double scaleBaseDelta(
      double raw, double intensity, double sensitivity, double cap) {
    if (intensity <= 0.5) return 0.0;
    return (raw * sensitivity.clamp(0.1, 1.0)).clamp(-cap, cap);
  }
}

class AffectionBatchService {
  AffectionBatchService._();

  static String buildSummaryPrompt(List<AffectionRound> rounds) {
    final body = rounds.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value;
      return '第$i轮\n用户：${r.user}\n角色：${r.assistant}';
    }).join('\n\n');
    return '请先简单总结以下四轮虚构角色扮演互动，只总结事实、情绪和关系推进，不评价用户，也不要输出好感度数值。控制在120字以内。\n$body';
  }

  static String buildJudgementPrompt(
      String summary, List<AffectionRound> rounds) {
    final body = rounds.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value;
      return '第$i轮：用户=${r.user}；角色=${r.assistant}';
    }).join('\n');
    return '''
根据四轮互动总结和原始内容，综合判断本轮关系好感度净变化。这是虚构角色扮演。
【四轮互动总结】
$summary
【原始四轮内容】
$body
只输出 JSON：
{"affection_delta":0.3,"affection_reason":"20字以内的简要原因","affection_detail":"30到120字的详细原因"}
affection_delta 范围为 -0.3 到 +0.8，允许为 0。affection_reason 必须非空且不超过20字。
delta 为 0 时只生成简要原因，affection_detail 省略或为空；delta 不为 0 时生成30到120字详细原因。
''';
  }

  static AffectionJudgement parseJudgement(String raw) {
    final root = JsonUtils.extractJson(raw) ?? const <String, dynamic>{};
    final delta = _readDelta(root['affection_delta']);
    final reason = normalizeReason(_readString(root['affection_reason']));
    return AffectionJudgement(
      delta: delta,
      reason: reason,
      detailedReason: delta.abs() < 0.0001
          ? ''
          : normalizeDetailedReason(
              _readString(root['affection_detail']),
              reason,
            ),
    );
  }

  static double _readDelta(Object? value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text.trim()) ?? 0.0,
      _ => 0.0,
    };
    if (!parsed.isFinite) return 0.0;
    return parsed.clamp(-0.3, 0.8);
  }

  static String _readString(Object? value) => value is String ? value : '';

  static String normalizeReason(String raw) {
    var reason = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (reason.isEmpty) reason = '这几轮互动让彼此关系暂时保持稳定';
    final runes = reason.runes.toList();
    return String.fromCharCodes(runes.take(math.min(20, runes.length)));
  }

  static String normalizeDetailedReason(String raw, String shortReason) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.runes.length < 30) {
      final fallback = '$shortReason；综合这四轮互动中的态度、情绪和关系推进，角色的好感度因此产生了这次变化。';
      final fallbackRunes = fallback.runes.toList();
      return String.fromCharCodes(
          fallbackRunes.take(math.min(120, fallbackRunes.length)));
    }
    final runes = clean.runes.toList();
    return String.fromCharCodes(runes.take(math.min(120, runes.length)));
  }
}
