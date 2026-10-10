import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/affection_log.dart';
import '../services/database_service.dart';

class AffectionLogPage extends StatefulWidget {
  final String conversationId;
  final String title;
  const AffectionLogPage({
    super.key,
    required this.conversationId,
    required this.title,
  });

  @override
  State<AffectionLogPage> createState() => _AffectionLogPageState();
}

class _AffectionLogPageState extends State<AffectionLogPage> {
  List<AffectionLog> _logs = [];
  Map<String, String> _personaNames = {};
  bool _loading = true;
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await DatabaseService.getAffectionLogs(widget.conversationId);
    final personas = await DatabaseService.getAIPersonas(widget.conversationId);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _personaNames = {for (final p in personas) p.id: p.name};
      _loading = false;
    });
  }

  String _nameFor(String? personaId) {
    final name = personaId == null ? null : _personaNames[personaId];
    return name?.isNotEmpty == true
        ? name!
        : (widget.title.trim().isEmpty ? '角色' : widget.title.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('好感度变化记录'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border,
                          size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('暂无好感度变化记录', style: theme.textTheme.bodyLarge),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _logs.length,
                  itemBuilder: (_, index) =>
                      _buildLogEntry(_logs[index], theme),
                ),
    );
  }

  Widget _buildLogEntry(AffectionLog log, ThemeData theme) {
    final isUp = log.delta > 0.005;
    final isDown = log.delta < -0.005;
    final isExpanded = _expandedIds.contains(log.id);
    final canExpand = log.detailedReason.trim().isNotEmpty;
    final deltaText = '${isUp ? '+' : ''}${log.delta.abs().toStringAsFixed(1)}';
    final deltaColor = isUp
        ? Colors.blue.shade600
        : isDown
            ? Colors.red.shade400
            : Colors.grey;
    final changeWord = isUp ? '上升' : (isDown ? '下降' : '无变化');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canExpand
            ? () => setState(() {
                  if (isExpanded) {
                    _expandedIds.remove(log.id);
                  } else {
                    _expandedIds.add(log.id);
                  }
                })
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.4),
                            children: [
                              TextSpan(text: _nameFor(log.personaId)),
                              const TextSpan(text: '因为'),
                              TextSpan(
                                text: log.reason,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: '，好感度$changeWord'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MM-dd HH:mm').format(log.createdAt),
                          style: TextStyle(
                              fontSize: 12, color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    deltaText,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: deltaColor),
                  ),
                ],
              ),
              if (isExpanded && canExpand) ...[
                const Divider(height: 20),
                Text(
                  log.detailedReason,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withOpacity(0.75)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
