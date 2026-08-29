import '../models/emotion_state.dart';
import '../models/message.dart';

class ReplyStylePolicy {
  static String? buildDirective({
    required List<Message> messages,
    required Map<String, String> emotionLabels,
    EmotionState? emotionState,
    String? selfEmotionTemplate,
  }) {
    final behavior = _selectBehaviorProfile(
      towardsUser: emotionLabels['towards_user'] ?? '平淡',
      selfState: emotionLabels['self_state'] ?? '平静',
      state: emotionState,
    );
    final rhythm = _selectRhythmProfile(messages);
    final repeated = _findRepeatedPhrases(messages);

    final sb = StringBuffer();
    sb.writeln('【生动表达策略】');
    sb.writeln('你必须把以下策略融入本轮回复，不要解释策略本身。');

    if (selfEmotionTemplate != null && selfEmotionTemplate.trim().isNotEmpty) {
      sb.writeln('情绪模板优先：');
      sb.writeln(selfEmotionTemplate.trim());
    }

    sb.writeln('');
    sb.writeln('1) 情绪行为映射');
    sb.writeln('开场方式：${behavior.openingStyle}');
    sb.writeln('句子长度：${behavior.sentenceLength}');
    sb.writeln('主动程度：${behavior.initiative}');
    sb.writeln('动作/感受描写：${behavior.actionDensity}');
    sb.writeln('追问频率：${behavior.questionRate}');

    sb.writeln('');
    sb.writeln('2) 节奏波动器');
    sb.writeln('当前节奏：${rhythm.name}');
    sb.writeln('本轮要求：${rhythm.rule}');

    if (repeated.isNotEmpty) {
      sb.writeln('');
      sb.writeln('3) 重复惩罚');
      sb.writeln('避免重复以下表述：${repeated.join('、')}');
      sb.writeln('请替换为同义但不同句式的表达。');
    }

    sb.writeln('');
    sb.writeln('最终要求：保持角色一致、自然、具体，避免客服腔和模板腔。');
    return sb.toString();
  }

  static _BehaviorProfile _selectBehaviorProfile({
    required String towardsUser,
    required String selfState,
    required EmotionState? state,
  }) {
    final marker = '$towardsUser|$selfState';

    if (_containsAny(marker, ['冷', '拒', '厌', '恶', '恨', '蔑'])) {
      return const _BehaviorProfile(
        openingStyle: '先短句定态度，再补一句理由',
        sentenceLength: '以短句为主，偶尔中句',
        initiative: '低到中，更多边界表达',
        actionDensity: '低，避免过多亲密动作',
        questionRate: '低，每段最多1问',
      );
    }

    if (_containsAny(marker, ['迷恋', '依恋', '喜欢', '心动', '热情', '崇拜', '黏'])) {
      return const _BehaviorProfile(
        openingStyle: '先给情绪回应，再推进一句互动',
        sentenceLength: '中句为主，夹少量短句',
        initiative: '中到高，主动推进话题',
        actionDensity: '中高，加入轻微动作和感受',
        questionRate: '中，每段1-2问',
      );
    }

    final aggression = state?.currentAggressionOther ?? 25.0;
    final libido = state?.currentLibidoOther ?? 25.0;
    if (aggression >= 35.0 && libido >= 30.0) {
      return const _BehaviorProfile(
        openingStyle: '先给有力回应，再提出要求或挑战',
        sentenceLength: '短中结合，节奏偏快',
        initiative: '高，强推进',
        actionDensity: '中，动作词偏直接',
        questionRate: '中低，少问多带',
      );
    }

    return const _BehaviorProfile(
      openingStyle: '先接住用户情绪，再自然延展',
      sentenceLength: '中句为主，避免过短重复',
      initiative: '中，回应与推进平衡',
      actionDensity: '中，点到即止',
      questionRate: '中，每段约1问',
    );
  }

  static _RhythmProfile _selectRhythmProfile(List<Message> messages) {
    final assistantCount = messages.where((m) => m.role == 'assistant').length;
    final phase = assistantCount % 3;
    switch (phase) {
      case 0:
        return const _RhythmProfile(
          name: '短促推进',
          rule: '前半段短句提速，后半段补一小段细节。',
        );
      case 1:
        return const _RhythmProfile(
          name: '平衡叙述',
          rule: '短句与中句交替，保持一收一放。',
        );
      default:
        return const _RhythmProfile(
          name: '细腻铺陈',
          rule: '先中句描述感受，再用短句收束。',
        );
    }
  }

  static List<String> _findRepeatedPhrases(List<Message> messages) {
    final recent = messages
        .where((m) => m.role == 'assistant' && m.content.trim().isNotEmpty)
        .toList();
    if (recent.length < 2) return const [];

    final tail = recent.length > 8 ? recent.sublist(recent.length - 8) : recent;
    final counts = <String, int>{};

    for (final msg in tail) {
      final chunks = msg.content
          .split(RegExp(r'[，。！？；\n,.!?;]'))
          .map((s) => s.trim())
          .where((s) => s.length >= 2 && s.length <= 14);
      for (final chunk in chunks) {
        counts[chunk] = (counts[chunk] ?? 0) + 1;
      }

      final compact = msg.content.replaceAll(RegExp(r'\s+'), '');
      if (compact.length >= 6) {
        final head = compact.substring(0, 6);
        counts[head] = (counts[head] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.length.compareTo(b.key.length);
      });

    return sorted.take(6).map((e) => e.key).toList();
  }

  static bool _containsAny(String source, List<String> needles) {
    for (final n in needles) {
      if (source.contains(n)) return true;
    }
    return false;
  }
}

class _BehaviorProfile {
  final String openingStyle;
  final String sentenceLength;
  final String initiative;
  final String actionDensity;
  final String questionRate;

  const _BehaviorProfile({
    required this.openingStyle,
    required this.sentenceLength,
    required this.initiative,
    required this.actionDensity,
    required this.questionRate,
  });
}

class _RhythmProfile {
  final String name;
  final String rule;

  const _RhythmProfile({required this.name, required this.rule});
}
