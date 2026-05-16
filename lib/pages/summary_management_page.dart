import 'package:flutter/material.dart';
import '../models/segment_summary.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';

class SummaryManagementPage extends StatefulWidget {
  final String conversationId;
  const SummaryManagementPage({super.key, required this.conversationId});

  @override
  State<SummaryManagementPage> createState() => _SummaryManagementPageState();
}

class _SummaryManagementPageState extends State<SummaryManagementPage> {
  List<SegmentSummary> _segments = [];
  bool _loading = true;
  bool _autoSummary = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final segments =
        await DatabaseService.getSegmentSummaries(widget.conversationId);
    final auto = await AuthService.getAutoSummaryEnabled();
    if (mounted) setState(() { _segments = segments; _loading = false; _autoSummary = auto; });
  }

  Future<void> _updateSummary(SegmentSummary seg, String content) async {
    final updated = seg.copyWith(content: content.trim());
    await DatabaseService.updateSegmentSummary(updated);
    final idx = _segments.indexWhere((s) => s.id == updated.id);
    if (idx != -1) setState(() => _segments[idx] = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('对话总结管理'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Auto-summary toggle
              SwitchListTile(
                title: const Text('AI 自动总结'),
                subtitle: const Text('归档时 AI 自动以角色口吻写日记式总结，关闭则弹出提示供你修改'),
                value: _autoSummary,
                onChanged: (v) async {
                  await AuthService.setAutoSummaryEnabled(v);
                  setState(() => _autoSummary = v);
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: _segments.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.note_alt_outlined, size: 48,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 12),
                    Text('暂无总结', style: Theme.of(context).textTheme.bodyLarge),
                  ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _segments.length,
                  itemBuilder: (_, i) => _buildSummaryCard(context, _segments[i]),
                ),
              ),
          ]),
    );
  }

  Widget _buildSummaryCard(BuildContext context, SegmentSummary seg) {
    final theme = Theme.of(context);
    final isEmpty = seg.content.trim().isEmpty;
    final controller = TextEditingController(text: seg.content);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.bookmark_outline, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('第 ${seg.segmentIndex * 5 + 1}-${(seg.segmentIndex + 1) * 5} 轮对话',
                style: theme.textTheme.titleSmall),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: controller, maxLines: 8, minLines: 3,
            decoration: InputDecoration(
              hintText: isEmpty ? '暂无日记，等待 AI 自动生成...' : '角色写的日记（可修改）...',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (!isEmpty)
              TextButton(
                  onPressed: () => _updateSummary(seg, ''),
                  child: const Text('清除')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final c = controller.text.trim();
                if (c != seg.content) _updateSummary(seg, c);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('总结已保存'), duration: Duration(seconds: 1)),
                );
              },
              child: const Text('保存'),
            ),
          ]),
        ]),
      ),
    );
  }
}
