import 'package:flutter/material.dart';
import '../models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleMode;
  final VoidCallback onSummaries;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
    required this.onToggleMode,
    required this.onSummaries,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstChar = conversation.title.isNotEmpty ? conversation.title.characters.first : '?';
    final isBookmark = conversation.mode == 'bookmark';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // Avatar circle
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isBookmark
                      ? [Colors.green.shade300, Colors.teal.shade500]
                      : [theme.colorScheme.primary.withOpacity(0.7), theme.colorScheme.primary],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(firstChar,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimary)),
            ),
            const SizedBox(width: 12),
            // Title + mode hint
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conversation.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    '${isBookmark ? '书签模式' : '总结模式'} · ${_formatDate(conversation.updatedAt)}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            // Mode toggle
            IconButton(
              onPressed: onToggleMode,
              icon: Icon(isBookmark ? Icons.flag : Icons.note_alt_outlined, size: 20,
                  color: isBookmark
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline),
              tooltip: isBookmark ? '切换到总结模式' : '切换到书签模式',
              visualDensity: VisualDensity.compact,
            ),
            // View summaries
            IconButton(
              onPressed: onSummaries,
              icon: Icon(isBookmark ? Icons.bookmarks : Icons.list_alt,
                  size: 20, color: theme.colorScheme.outline),
              tooltip: isBookmark ? '管理书签' : '查看总结',
              visualDensity: VisualDensity.compact,
            ),
            // Delete
            IconButton(
              onPressed: () => _confirmDelete(context),
              icon: Icon(Icons.delete_outline, size: 20,
                  color: theme.colorScheme.error.withOpacity(0.6)),
              visualDensity: VisualDensity.compact,
            ),
          ]),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除「${conversation.title}」？\n所有消息和总结将被永久删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              onDelete();
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
