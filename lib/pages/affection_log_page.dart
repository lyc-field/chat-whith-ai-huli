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

  String get _defaultName {
    final t = widget.title.trim();
    if (t.isNotEmpty && t != '新对话') return t;
    return '角色';
  }

  String _nameFor(String? personaId) =>
      personaId != null ? (_personaNames[personaId] ?? '角色') : _defaultName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _logs = await DatabaseService.getAffectionLogs(widget.conversationId);
    // Load persona names
    final personas = await DatabaseService.getAIPersonas(widget.conversationId);
    if (mounted) {
      setState(() {
        _personaNames = {for (final p in personas) p.id: p.name};
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('好感度变化记录'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite_border, size: 64,
                        color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('暂无好感度变化记录',
                        style: theme.textTheme.bodyLarge),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _logs.length,
                  itemBuilder: (_, i) => _buildLogEntry(_logs[i], theme),
                ),
    );
  }

  Widget _buildLogEntry(AffectionLog log, ThemeData theme) {
    final isUp = log.delta > 0.005;
    final isDown = log.delta < -0.005;
    final isExpanded = _expandedIds.contains(log.id);
    final time = DateFormat('MM-dd HH:mm').format(log.createdAt);
    final absDelta = log.delta.abs();
    final deltaStr = '${isUp ? "+" : ""}${absDelta.toStringAsFixed(1)}';
    final deltaColor = isUp ? Colors.blue.shade600 : (isDown ? Colors.red.shade400 : Colors.grey);
    final hasChange = absDelta > 0.05;
    final changeWord = hasChange ? (isUp ? '上升' : '下降') : '无变化';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (log.userMessage.isNotEmpty || log.aiMessage.isNotEmpty) {
            setState(() {
              isExpanded
                  ? _expandedIds.remove(log.id)
                  : _expandedIds.add(log.id);
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: reason text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                            children: [
                              TextSpan(text: _nameFor(log.personaId)),
                              TextSpan(
                                text: '因为',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6)),
                              ),
                              TextSpan(
                                text: log.reason,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface),
                              ),
                              TextSpan(
                                text: '，好感度$changeWord',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right: delta value
                  Text(
                    deltaStr,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: deltaColor,
                    ),
                  ),
                ],
              ),
              // Expandable: judged messages
              if (isExpanded &&
                  (log.userMessage.isNotEmpty || log.aiMessage.isNotEmpty)) ...[
                const Divider(height: 20),
                _buildMsgPreview('用户', log.userMessage, theme),
                const SizedBox(height: 8),
                _buildMsgPreview('AI', log.aiMessage, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMsgPreview(String label, String text, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
