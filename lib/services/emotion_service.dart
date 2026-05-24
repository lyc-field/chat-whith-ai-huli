import 'package:flutter/foundation.dart';
import '../models/emotion_state.dart';
import 'deepseek_service.dart';
import 'json_utils.dart';

/// Emotion lookup tables ported from emotion_tables.py
class EmotionTables {
  static double _mapToBracket(double value) {
    for (final b in [0.0, 12.5, 25.0, 37.5, 50.0]) {
      if (value <= b) return b;
    }
    return 50.0;
  }

  static int _getAffectionLevel(double affection) {
    if (affection < 12.5) return 0;
    if (affection < 37.5) return 25;
    if (affection < 62.5) return 50;
    if (affection < 87.5) return 75;
    return 100;
  }

  static const Map<int, Map<String, String>> _towardsUserTable = {
    0: {
      '50.0,0.0': '痴迷(病态)', '50.0,12.5': '纠缠(偏执)', '50.0,25.0': '憎恨', '50.0,37.5': '毁灭性恨', '50.0,50.0': '同归于尽',
      '37.5,0.0': '依赖(绝望)', '37.5,12.5': '烦躁', '37.5,25.0': '厌恶', '37.5,37.5': '仇恨', '37.5,50.0': '残暴',
      '25.0,0.0': '冷淡', '25.0,12.5': '无聊', '25.0,25.0': '轻蔑', '25.0,37.5': '蔑视', '25.0,50.0': '冷酷',
      '12.5,0.0': '回避', '12.5,12.5': '疏离', '12.5,25.0': '嫌弃', '12.5,37.5': '恶心', '12.5,50.0': '憎恶',
      '0.0,0.0': '无视', '0.0,12.5': '不存在', '0.0,25.0': '否定', '0.0,37.5': '驱逐', '0.0,50.0': '湮灭',
    },
    25: {
      '50.0,0.0': '执着', '50.0,12.5': '猜疑', '50.0,25.0': '嫉妒', '50.0,37.5': '报复欲', '50.0,50.0': '毁灭欲',
      '37.5,0.0': '渴求', '37.5,12.5': '试探', '37.5,25.0': '敌意', '37.5,37.5': '愤怒', '37.5,50.0': '仇恨',
      '25.0,0.0': '普通', '25.0,12.5': '不耐烦', '25.0,25.0': '竞争', '25.0,37.5': '攻击玩笑', '25.0,50.0': '讽刺',
      '12.5,0.0': '礼貌', '12.5,12.5': '无聊', '12.5,25.0': '烦躁', '12.5,37.5': '厌恶', '12.5,50.0': '憎恨',
      '0.0,0.0': '冷漠', '0.0,12.5': '沉默', '0.0,25.0': '回避', '0.0,37.5': '拒绝', '0.0,50.0': '驱赶',
    },
    50: {
      '50.0,0.0': '迷恋', '50.0,12.5': '占有', '50.0,25.0': '嫉妒', '50.0,37.5': '施虐倾向', '50.0,50.0': '毁灭性爱',
      '37.5,0.0': '依恋', '37.5,12.5': '激情', '37.5,25.0': '纠缠', '37.5,37.5': '报复', '37.5,50.0': '仇恨',
      '25.0,0.0': '喜欢', '25.0,12.5': '渴望', '25.0,25.0': '竞争', '25.0,37.5': '愤怒', '25.0,50.0': '残暴',
      '12.5,0.0': '好感', '12.5,12.5': '无聊', '12.5,25.0': '烦躁', '12.5,37.5': '厌恶', '12.5,50.0': '憎恨',
      '0.0,0.0': '冷漠', '0.0,12.5': '疏离', '0.0,25.0': '轻蔑', '0.0,37.5': '蔑视', '0.0,50.0': '冷酷',
    },
    75: {
      '50.0,0.0': '痴迷', '50.0,12.5': '占有欲', '50.0,25.0': '吃醋', '50.0,37.5': '霸道', '50.0,50.0': '毁灭占有',
      '37.5,0.0': '依恋(甜)', '37.5,12.5': '热情', '37.5,25.0': '撒娇纠缠', '37.5,37.5': '管教欲', '37.5,50.0': '因爱生恨',
      '25.0,0.0': '欣赏', '25.0,12.5': '心动', '25.0,25.0': '争宠', '25.0,37.5': '着急', '25.0,50.0': '暴躁后悔',
      '12.5,0.0': '友善', '12.5,12.5': '小无聊', '12.5,25.0': '小烦躁', '12.5,37.5': '恼火', '12.5,50.0': '气话哄好',
      '0.0,0.0': '平淡', '0.0,12.5': '安静', '0.0,25.0': '冷一下', '0.0,37.5': '生闷气', '0.0,50.0': '冷战',
    },
    100: {
      '50.0,0.0': '崇拜', '50.0,12.5': '完全占有', '50.0,25.0': '吃醋失控', '50.0,37.5': '施虐play', '50.0,50.0': '共依存',
      '37.5,0.0': '离不开', '37.5,12.5': '热情似火', '37.5,25.0': '黏人烦', '37.5,37.5': '调教欲', '37.5,50.0': '相爱相杀',
      '25.0,0.0': '溺爱', '25.0,12.5': '渴望融合', '25.0,25.0': '撒娇争夺', '25.0,37.5': '炸毛', '25.0,50.0': '虐恋',
      '12.5,0.0': '安心', '12.5,12.5': '小撒娇', '12.5,25.0': '小赌气', '12.5,37.5': '假生气', '12.5,50.0': '闹别扭',
      '0.0,0.0': '平静幸福', '0.0,12.5': '沉默有爱', '0.0,25.0': '闷气心软', '0.0,37.5': '委屈', '0.0,50.0': '冷战等哄',
    },
  };

  static const Map<String, String> _selfTable = {
    '50.0,0.0': '自恋', '50.0,12.5': '自满', '50.0,25.0': '自傲', '50.0,37.5': '自大', '50.0,50.0': '自毁冲动',
    '37.5,0.0': '自爱', '37.5,12.5': '自怜', '37.5,25.0': '自责', '37.5,37.5': '自卑', '37.5,50.0': '自我仇恨',
    '25.0,0.0': '自信', '25.0,12.5': '平淡', '25.0,25.0': '内疚', '25.0,37.5': '自我厌恶', '25.0,50.0': '自残欲',
    '12.5,0.0': '自保', '12.5,12.5': '空虚', '12.5,25.0': '羞愧', '12.5,37.5': '自贬', '12.5,50.0': '自毁欲',
    '0.0,0.0': '无我', '0.0,12.5': '麻木', '0.0,25.0': '自我否定', '0.0,37.5': '自我毁灭', '0.0,50.0': '湮灭',
  };

  static Map<String, String> getEmotionDescription(EmotionState state) {
    final affLevel = _getAffectionLevel(state.affection);
    final loB = _mapToBracket(state.currentLibidoOther);
    final aoB = _mapToBracket(state.currentAggressionOther);
    final lsB = _mapToBracket(state.currentLibidoSelf);
    final asB = _mapToBracket(state.currentAggressionSelf);

    final towardsKey = '${loB.toStringAsFixed(1)},${aoB.toStringAsFixed(1)}';
    final selfKey = '${lsB.toStringAsFixed(1)},${asB.toStringAsFixed(1)}';

    final table = _towardsUserTable[affLevel] ?? _towardsUserTable[50]!;
    final towardsUser = table[towardsKey] ?? '未知';
    final selfState = _selfTable[selfKey] ?? '未知';

    return {'towards_user': towardsUser, 'self_state': selfState};
  }

  /// Check if self-destruction倾诉 mode is triggered
  static bool isSelfDestructMode(EmotionState state) {
    return state.currentAggressionSelf >= 37.5 && state.currentLibidoSelf <= 12.5;
  }

  /// Get grid data for 对用户 emotion table. Returns list of rows (Y=攻击性), each row is list of cells.
  static List<List<String>> getTowardsUserGrid(EmotionState state) {
    final affLevel = _getAffectionLevel(state.affection);
    final table = _towardsUserTable[affLevel] ?? _towardsUserTable[50]!;
    final brackets = [0.0, 12.5, 25.0, 37.5, 50.0];
    final grid = <List<String>>[];
    for (final aggression in brackets.reversed) {
      // aggression = Y axis (rows, top to bottom: 50→0)
      final row = <String>[];
      for (final libido in brackets) {
        // libido = X axis (columns, left to right: 0→50)
        final key = '${libido.toStringAsFixed(1)},${aggression.toStringAsFixed(1)}';
        row.add(table[key] ?? '?');
      }
      grid.add(row);
    }
    return grid; // row 0 = 攻击性50, row 4 = 攻击性0
  }

  /// Get grid data for 自身 emotion table.
  static List<List<String>> getSelfGrid() {
    final brackets = [0.0, 12.5, 25.0, 37.5, 50.0];
    final grid = <List<String>>[];
    for (final selfAgg in brackets.reversed) {
      final row = <String>[];
      for (final selfLib in brackets) {
        final key = '${selfLib.toStringAsFixed(1)},${selfAgg.toStringAsFixed(1)}';
        row.add(_selfTable[key] ?? '?');
      }
      grid.add(row);
    }
    return grid;
  }

  /// Get the bracket indices of current state (for highlighting)
  static ({int col, int row}) getTowardsUserBracket(EmotionState state) {
    final loB = _mapToBracket(state.currentLibidoOther);
    final aoB = _mapToBracket(state.currentAggressionOther);
    final brackets = [0.0, 12.5, 25.0, 37.5, 50.0];
    final col = brackets.indexOf(loB);   // X = 力比多
    final row = 4 - brackets.indexOf(aoB); // Y = 攻击性 (reversed in grid)
    return (col: col, row: row);
  }

  static ({int col, int row}) getSelfBracket(EmotionState state) {
    final lsB = _mapToBracket(state.currentLibidoSelf);
    final asB = _mapToBracket(state.currentAggressionSelf);
    final brackets = [0.0, 12.5, 25.0, 37.5, 50.0];
    final col = brackets.indexOf(lsB);
    final row = 4 - brackets.indexOf(asB);
    return (col: col, row: row);
  }
}

/// Decay computation ported from decay.py
class DecayCalculator {
  /// Compute decay delta toward baseline.
  /// Returns the correction amount to add to current value.
  static double computeDecay(double elapsedHours, double initialDeviation, double durationHours) {
    double dur = durationHours <= 0 ? 0.5 : durationHours;
    if (elapsedHours >= dur) return -initialDeviation;
    final ratio = elapsedHours / dur;
    final decayAmount = initialDeviation * (ratio * ratio);
    return -decayAmount;
  }

  /// Apply decay to a single emotion dimension
  static double applyDecay(double current, double baseline, double elapsedHours, double durationHours) {
    final deviation = current - baseline;
    if (deviation.abs() < 0.001) return current;
    final delta = computeDecay(elapsedHours, deviation, durationHours);
    return (current + delta).clamp(0.0, 50.0);
  }
}

/// Unconscious LLM analysis — ported from unconscious.py
class EmotionAnalyzer {
  final DeepSeekService _service;

  EmotionAnalyzer(this._service);

  String _buildPrompt(EmotionState state, String history, String latestMsg) {
    final historySnippet = history.length > 2000 ? history.substring(history.length - 2000) : history;
    final turn = state.turnCount;
    return '''
你是潜意识的数值调节器。根据用户最新消息和对话历史，分析对AI情绪的影响。

**重要规则**：
1. 必须对"他力比多"和"他攻击性"的**当前值**给出非零的调整增量（即使是很小的 ±0.1），因为每次互动都会引起情绪波动。
2. 对"自力比多"和"自攻击性"的当前值也建议给出非零增量，除非对话完全中性。
3. 同时评估本次互动是否影响**长期印象（基线值）**：
   - 对他人的基线（原他力比多/原他攻击性）：当前是第 $turn 轮对话。
     * 若 turn_count <= 10，基线变化可以较明显（增量范围 -1.5 ~ +1.5）。
     * 若 turn_count > 10，基线变化必须极小（增量范围 -0.2 ~ +0.2），因为初印象已形成。
   - 对自身的基线（原自力比多/原自攻击性）：始终很难改变，增量范围 -0.2 ~ +0.2。
4. **场景强度识别**：判断当前对话场景的情感强度：
   - 高强度（2.0）：生死离别、深爱表白、极度崇拜、仇恨爆发、自毁倾诉、重大牺牲
   - 中强度（1.0）：普通争执、日常关心、轻度调侃、常规互动
   - 低强度（0.5）：寒暄、中性闲聊、无关话题、简单应答
   输出 `intensity` 字段。

**情绪解读指南（务必遵循）**：
- 用户表达喜爱、关心、赞美、感谢、不舍、祝福 → 他力比多 ↑，攻击性 ↓
- 用户表达批评、指责、冷漠、拒绝、贬低 → 他力比多 ↓，攻击性 ↑
- 用户表达悲伤、无助、自我否定 → 他力比多 ↑（安慰欲），但若用户攻击AI则攻击性 ↑
- 用户长时间未互动且无合理理由 → 攻击性 ↑（微恼），力比多 ↓
- 用户道别但语气温暖 → 他力比多 ↑↑，攻击性 ↓↓
- 用户调侃、玩笑但无恶意 → 他力比多可能微降，攻击性微升（傲娇反应）
- 对自身：获得正面反馈时自力比多 ↑，被否定或自省时自攻击性 ↑

当前状态：
- 对话轮次：第 $turn 轮
- 好感度：${state.affection.toStringAsFixed(1)}/100
- 对他基线：原他力比多 ${state.baseLibidoOther.toStringAsFixed(1)}，原他攻击性 ${state.baseAggressionOther.toStringAsFixed(1)}
- 对他当前：他力比多 ${state.currentLibidoOther.toStringAsFixed(1)}，他攻击性 ${state.currentAggressionOther.toStringAsFixed(1)}
- 对己基线：原自力比多 ${state.baseLibidoSelf.toStringAsFixed(1)}，原自攻击性 ${state.baseAggressionSelf.toStringAsFixed(1)}
- 对己当前：自力比多 ${state.currentLibidoSelf.toStringAsFixed(1)}，自攻击性 ${state.currentAggressionSelf.toStringAsFixed(1)}

最近对话历史：
$historySnippet

用户最新消息：$latestMsg

请输出 JSON 格式：
{
  "libido_other_delta": 0.0,
  "aggression_other_delta": 0.0,
  "libido_self_delta": 0.0,
  "aggression_self_delta": 0.0,
  "base_libido_other_delta": 0.0,
  "base_aggression_other_delta": 0.0,
  "base_libido_self_delta": 0.0,
  "base_aggression_self_delta": 0.0,
  "intensity": 1.0
}

只输出 JSON，不要其他文字。''';
  }

  Map<String, dynamic> _parseJson(String text) {
    return JsonUtils.extractJson(text) ?? _defaultResponse();
  }

  Map<String, dynamic> _clampDeltas(Map<String, dynamic> data, int turnCount) {
    final clamped = <String, dynamic>{};
    clamped['libido_other_delta'] = ((data['libido_other_delta'] as num?)?.toDouble() ?? 0.0).clamp(-2.0, 2.0);
    clamped['aggression_other_delta'] = ((data['aggression_other_delta'] as num?)?.toDouble() ?? 0.0).clamp(-2.0, 2.0);
    clamped['libido_self_delta'] = ((data['libido_self_delta'] as num?)?.toDouble() ?? 0.0).clamp(-2.0, 2.0);
    clamped['aggression_self_delta'] = ((data['aggression_self_delta'] as num?)?.toDouble() ?? 0.0).clamp(-2.0, 2.0);
    clamped['affection_delta'] = ((data['affection_delta'] as num?)?.toDouble() ?? 0.0).clamp(-0.5, 0.5);

    if (turnCount <= 10) {
      clamped['base_libido_other_delta'] = ((data['base_libido_other_delta'] as num?)?.toDouble() ?? 0.0).clamp(-1.5, 1.5);
      clamped['base_aggression_other_delta'] = ((data['base_aggression_other_delta'] as num?)?.toDouble() ?? 0.0).clamp(-1.5, 1.5);
    } else {
      clamped['base_libido_other_delta'] = ((data['base_libido_other_delta'] as num?)?.toDouble() ?? 0.0).clamp(-0.2, 0.2);
      clamped['base_aggression_other_delta'] = ((data['base_aggression_other_delta'] as num?)?.toDouble() ?? 0.0).clamp(-0.2, 0.2);
    }
    clamped['base_libido_self_delta'] = ((data['base_libido_self_delta'] as num?)?.toDouble() ?? 0.0).clamp(-0.2, 0.2);
    clamped['base_aggression_self_delta'] = ((data['base_aggression_self_delta'] as num?)?.toDouble() ?? 0.0).clamp(-0.2, 0.2);

    double intensity = (data['intensity'] as num?)?.toDouble() ?? 1.0;
    clamped['intensity'] = intensity.clamp(0.5, 2.0);
    final rawReason = (data['reason'] as String?) ?? '';
    var clean = rawReason
        .replaceAll(RegExp(r'[\n\r\t]'), ' ')
        .trim();
    clamped['reason'] = clean;
    return clamped;
  }

  Map<String, dynamic> _ensureNonZero(Map<String, dynamic> deltas, EmotionState state) {
    for (final key in ['libido_other_delta', 'aggression_other_delta']) {
      if ((deltas[key] as double).abs() < 0.001) {
        deltas[key] = state.affection > 60 ? 0.1 : (state.affection < 40 ? -0.1 : 0.05);
      }
    }
    return deltas;
  }

  Map<String, dynamic> _defaultResponse() {
    return {
      'libido_other_delta': 0.05,
      'aggression_other_delta': 0.05,
      'libido_self_delta': 0.0,
      'aggression_self_delta': 0.0,
      'affection_delta': 0.0,
      'base_libido_other_delta': 0.0,
      'base_aggression_other_delta': 0.0,
      'base_libido_self_delta': 0.0,
      'base_aggression_self_delta': 0.0,
      'intensity': 1.0,
      'reason': '',
    };
  }

  /// Call unconscious LLM to analyze conversation and return emotion deltas.
  Future<Map<String, dynamic>> analyzeAndAdjust({
    required EmotionState state,
    required String history,
    required String latestMsg,
  }) async {
    try {
      final prompt = _buildPrompt(state, history, latestMsg);
      final response = await _service.chatRaw(prompt, '你是一个情绪数值调节器，只输出 JSON，不添加任何解释。');
      final deltas = _parseJson(response);
      final clamped = _clampDeltas(deltas, state.turnCount);
      return _ensureNonZero(clamped, state);
    } catch (e) {
      debugPrint('[EmotionService] 情感分析失败，使用默认值: $e');
      return _defaultResponse();
    }
  }
}
