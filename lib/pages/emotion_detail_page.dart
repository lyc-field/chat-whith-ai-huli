import 'package:flutter/material.dart';
import '../models/emotion_state.dart';
import '../services/database_service.dart';
import '../services/emotion_service.dart';
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
    final state = await DatabaseService.getEmotionState(widget.conversationId);
    if (mounted) {
      setState(() {
        _state = state;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('情感详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_state == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('情感详情')),
        body: const Center(child: Text('暂无情感数据')),
      );
    }

    final labels = EmotionTables.getEmotionDescription(_state!);
    final isSD = EmotionTables.isSelfDestructMode(_state!);

    return Scaffold(
      appBar: AppBar(title: const Text('情感详情'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ─── Info table ───
          _buildInfoTable(labels, isSD),
          const SizedBox(height: 16),
          // ─── 对用户 grid ───
          Text('对用户的情感', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('好感度 = ${_state!.affection.toStringAsFixed(1)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 8),
          EmotionGrid.towardsUser(state: _state!),
          const SizedBox(height: 20),
          // ─── 自身 grid ───
          Text('对自身的情感', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          EmotionGrid.self(state: _state!),
        ],
      ),
    );
  }

  Widget _buildInfoTable(Map<String, String> labels, bool isSD) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          columnWidths: const {0: FixedColumnWidth(90), 1: FlexColumnWidth()},
          children: [
            _infoRow('好感度', '${_state!.affection.toStringAsFixed(1)} / 100', Colors.pink),
            _infoRow('他力比多', '${_state!.currentLibidoOther.toStringAsFixed(1)} / 50  (基线 ${_state!.baseLibidoOther.toStringAsFixed(1)})', Colors.blue),
            _infoRow('他攻击性', '${_state!.currentAggressionOther.toStringAsFixed(1)} / 50  (基线 ${_state!.baseAggressionOther.toStringAsFixed(1)})', Colors.red),
            _infoRow('自力比多', '${_state!.currentLibidoSelf.toStringAsFixed(1)} / 50  (基线 ${_state!.baseLibidoSelf.toStringAsFixed(1)})', Colors.indigo),
            _infoRow('自攻击性', '${_state!.currentAggressionSelf.toStringAsFixed(1)} / 50  (基线 ${_state!.baseAggressionSelf.toStringAsFixed(1)})', Colors.orange),
            _infoRow('对用户', labels['towards_user'] ?? '', null),
            _infoRow('自身', labels['self_state'] ?? '', null),
            _infoRow('对话轮次', '${_state!.turnCount}', null),
            if (isSD)
              _infoRow('特殊状态', '⚠ 自毁倾诉模式', Colors.red),
          ],
        ),
      ),
    );
  }

  TableRow _infoRow(String label, String value, Color? color) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: color ?? Theme.of(context).colorScheme.onSurface)),
        ),
      ],
    );
  }
}
