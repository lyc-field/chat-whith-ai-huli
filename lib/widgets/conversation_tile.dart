import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onSummaries;
  final VoidCallback? onToggleMode;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
    this.isSelected = false,
    this.onSummaries,
    this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = _formatDate(conversation.updatedAt);

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除对话'),
            content: const Text('删除后无法恢复，确定吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: theme.colorScheme.secondaryContainer.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
          child: Icon(Icons.chat_bubble_outline_rounded, size: 20,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant),
        ),
        title: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(dateStr),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode toggle: flag icon (bookmark) or summary icon
            if (onToggleMode != null)
              GestureDetector(
                onTap: onToggleMode,
                child: Container(
                  width: 32, height: 32,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: conversation.mode == 'bookmark'
                        ? Colors.green.shade100
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: conversation.mode == 'bookmark'
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Icon(
                    Icons.flag,
                    size: 18,
                    color: conversation.mode == 'bookmark'
                        ? Colors.green.shade700
                        : Colors.grey,
                  ),
                ),
              ),
            if (onSummaries != null && conversation.mode == 'summary')
              IconButton(
                  icon: const Icon(Icons.note_alt_outlined, size: 18),
                  tooltip: '查看总结',
                  onPressed: onSummaries),
            if (onSummaries != null && conversation.mode == 'bookmark')
              IconButton(
                  icon: const Icon(Icons.flag, size: 18),
                  tooltip: '书签管理',
                  onPressed: onSummaries),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18,
                  color: Theme.of(context).colorScheme.error),
              tooltip: '删除',
              onPressed: () => _showDeleteConfirm(context),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定要删除「${conversation.title}」吗？\n所有聊天记录将被永久删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              onDelete();
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(date);
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM-dd').format(date);
  }
}
