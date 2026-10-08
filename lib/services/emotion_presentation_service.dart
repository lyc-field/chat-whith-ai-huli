import '../models/emotion_state.dart';
import 'emotion_service.dart';

/// User-facing interpretation of the internal emotion state.
///
/// The numerical model remains available to advanced users, while this
/// presentation object keeps the default UI focused on relationship language.
class EmotionPresentation {
  final String relationshipStage;
  final String towardsUserEmotion;
  final String selfEmotion;
  final String trend;
  final String trendDescription;
  final String summary;
  final bool isSelfDestructMode;

  const EmotionPresentation({
    required this.relationshipStage,
    required this.towardsUserEmotion,
    required this.selfEmotion,
    required this.trend,
    required this.trendDescription,
    required this.summary,
    required this.isSelfDestructMode,
  });
}

class EmotionPresentationService {
  EmotionPresentationService._();

  /// Convert the internal affection range (-15..100) to relationship language.
  static String relationshipStageFor(double affection) {
    if (affection < 0) return '敌意';
    if (affection < 20) return '陌生';
    if (affection < 40) return '熟悉';
    if (affection < 65) return '亲近';
    if (affection < 85) return '亲密';
    return '深爱';
  }

  static EmotionPresentation summarize(EmotionState state) {
    final labels = EmotionTables.getEmotionDescription(state);
    final towards = _labelOrFallback(labels['towards_user']);
    final self = _labelOrFallback(labels['self_state']);
    final trend = _trendFor(state);

    return EmotionPresentation(
      relationshipStage: relationshipStageFor(state.affection),
      towardsUserEmotion: towards,
      selfEmotion: self,
      trend: trend,
      trendDescription: _trendDescriptionFor(trend),
      summary: '当前对你的感受是“$towards”，内在状态是“$self”。',
      isSelfDestructMode: EmotionTables.isSelfDestructMode(state),
    );
  }

  static String _labelOrFallback(String? value) {
    final label = value?.trim();
    return label == null || label.isEmpty ? '暂时无法判断' : label;
  }

  static String _trendFor(EmotionState state) {
    final towardsScore =
        _delta(state.currentLibidoOther, state.baseLibidoOther) -
            _delta(state.currentAggressionOther, state.baseAggressionOther);
    final selfScore = _delta(state.currentLibidoSelf, state.baseLibidoSelf) -
        _delta(state.currentAggressionSelf, state.baseAggressionSelf);
    final score = towardsScore + selfScore * 0.5;

    if (score >= 3) return '正在升温';
    if (score <= -3) return '正在降温';
    return '相对稳定';
  }

  static double _delta(double current, double baseline) => current - baseline;

  static String _trendDescriptionFor(String trend) {
    switch (trend) {
      case '正在升温':
        return '最近的情绪变化更倾向于靠近和建立连接。';
      case '正在降温':
        return '最近的情绪变化更倾向于拉远和保持距离。';
      default:
        return '最近的情绪变化不明显，关系暂时保持稳定。';
    }
  }
}
