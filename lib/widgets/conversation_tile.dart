import 'dart:io';
import 'package:flutter/material.dart';
import '../models/conversation.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleMode;
  final VoidCallback onSummaries;
  final VoidCallback? onAvatarTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
    required this.onToggleMode,
    required this.onSummaries,
    this.onAvatarTap,
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
    final firstChar = conversation.title.isNotEmpty
        ? conversation.title.characters.first
        : '?';
    final isBookmark = conversation.mode == 'bookmark';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            // Avatar circle
            GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isBookmark
                        ? [Colors.green.shade300, Colors.teal.shade500]
                        : [
                            theme.colorScheme.primary.withOpacity(0.7),
                            theme.colorScheme.primary
                          ],
                  ),
                  shape: BoxShape.circle,
                  image: conversation.avatarPath != null && conversation.avatarPath!.isNotEmpty
                      ? DecorationImage(
                          image: FileImage(File(conversation.avatarPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isBookmark ? Colors.teal : theme.colorScheme.primary)
                              .withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]),
              alignment: Alignment.center,
              child: conversation.avatarPath != null && conversation.avatarPath!.isNotEmpty
                  ? null
                  : Text(firstChar,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onPrimary)),
              ),
            ),
            const SizedBox(width: 8),
            // Title + mode hint
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(isBookmark ? Icons.flag : Icons.note_alt_outlined,
                          size: 14, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        '${isBookmark ? '书签模式' : '总结模式'} · ${_formatDate(conversation.updatedAt)}',
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.outline,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Mode toggle
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onToggleMode,
                icon: Icon(isBookmark ? Icons.flag : Icons.note_alt_outlined,
                    size: 20,
                    color: isBookmark
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline),
                tooltip: isBookmark ? '切换到总结模式' : '切换到书签模式',
                visualDensity: VisualDensity.compact,
              ),
            ),
            // View summaries
            Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onSummaries,
                icon: Icon(isBookmark ? Icons.bookmarks : Icons.list_alt,
                    size: 20, color: theme.colorScheme.outline),
                tooltip: isBookmark ? '管理书签' : '查看总结',
                visualDensity: VisualDensity.compact,
              ),
            ),
            // Delete
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () => _confirmDelete(context),
                icon: Icon(Icons.delete_outline,
                    size: 20, color: theme.colorScheme.error),
                visualDensity: VisualDensity.compact,
              ),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
