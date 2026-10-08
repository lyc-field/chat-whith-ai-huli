import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/emotion_state.dart';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
import '../services/emotion_presentation_service.dart';
import '../widgets/emotion_grid.dart';

class EmotionDetailPage extends StatefulWidget {
  final String conversationId;
  final String title;

  const EmotionDetailPage({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  State<EmotionDetailPage> createState() => _EmotionDetailPageState();
}

class _EmotionDetailPageState extends State<EmotionDetailPage> {
  EmotionState? _state;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<ChatProvider>();
    final state = provider.isNewFormat && provider.currentPersonaId != null
        ? await DatabaseService.getPersonaEmotionState(
            widget.conversationId,
            provider.currentPersonaId!,
          )
        : await DatabaseService.getEmotionState(widget.conversationId);

    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_state == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('暂无情绪数据')),
      );
    }

    final state = _state!;
    final presentation = EmotionPresentationService.summarize(state);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? '情绪状态' : widget.title),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildOverviewCard(presentation, state),
          const SizedBox(height: 12),
          _buildTrendCard(presentation),
          const SizedBox(height: 8),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.tune),
              title: const Text('高级详情'),
              subtitle: const Text('查看四维数值、基线和情绪矩阵'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                _buildInfoTable(presentation, state),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '对用户的情绪',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 4),
                _buildAffectionCaption(state),
                const SizedBox(height: 8),
                EmotionGrid.towardsUser(state: state),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '对自身的情绪',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                EmotionGrid.self(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    EmotionPresentation presentation,
    EmotionState state,
  ) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('关系状态', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  '${state.affection.toStringAsFixed(1)} / 100',
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              presentation.relationshipStage,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(presentation.summary, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(EmotionPresentation presentation) {
    final theme = Theme.of(context);
    final isStable = presentation.trend == '相对稳定';
    final color =
        isStable ? theme.colorScheme.outline : theme.colorScheme.primary;
    final icon = presentation.trend == '正在升温'
        ? Icons.trending_up
        : presentation.trend == '正在降温'
            ? Icons.trending_down
            : Icons.trending_flat;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('近期趋势：${presentation.trend}'),
        subtitle: Text(presentation.trendDescription),
      ),
    );
  }

  Widget _buildAffectionCaption(EmotionState state) {
    return Text(
      '好感度 = ${state.affection.toStringAsFixed(1)}',
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildInfoTable(
    EmotionPresentation presentation,
    EmotionState state,
  ) {
    return Table(
      columnWidths: const {0: FixedColumnWidth(100), 1: FlexColumnWidth()},
      children: [
        _infoRow('对用户情绪', presentation.towardsUserEmotion, null),
        _infoRow('自身状态', presentation.selfEmotion, null),
        _infoRow(
          '对外亲近感',
          '${state.currentLibidoOther.toStringAsFixed(1)} / 50（基线 ${state.baseLibidoOther.toStringAsFixed(1)}）',
          Colors.blue,
        ),
        _infoRow(
          '对外攻击性',
          '${state.currentAggressionOther.toStringAsFixed(1)} / 50（基线 ${state.baseAggressionOther.toStringAsFixed(1)}）',
          Colors.red,
        ),
        _infoRow(
          '自我肯定',
          '${state.currentLibidoSelf.toStringAsFixed(1)} / 50（基线 ${state.baseLibidoSelf.toStringAsFixed(1)}）',
          Colors.indigo,
        ),
        _infoRow(
          '自我压力',
          '${state.currentAggressionSelf.toStringAsFixed(1)} / 50（基线 ${state.baseAggressionSelf.toStringAsFixed(1)}）',
          Colors.orange,
        ),
        _infoRow('对话轮次', '${state.turnCount}', null),
        if (presentation.isSelfDestructMode)
          _infoRow('特殊状态', '高风险：自毁倾向', Colors.red),
      ],
    );
  }

  TableRow _infoRow(String label, String value, Color? color) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
