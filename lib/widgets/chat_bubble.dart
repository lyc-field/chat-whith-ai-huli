import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../services/deepseek_service.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool showTimestamp;
  final ValueChanged<String>? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRegenerate;
  final VoidCallback? onToggleBookmark;
  final bool archived;

  const ChatBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
    this.onEdit,
    this.onDelete,
    this.onRegenerate,
    this.onToggleBookmark,
    this.archived = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final isEmpty = message.content.isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: archived
                  ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
                  : isUser
                      ? theme.colorScheme.primaryContainer.withOpacity(0.8)
                      : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 18),
              ),
              boxShadow: isEmpty ? null : [
                BoxShadow(
                  color: (isUser ? theme.colorScheme.primary : theme.colorScheme.onSurface)
                      .withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: isEmpty
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : SelectableText(
                    message.content,
                    style: TextStyle(
                      fontSize: archived ? 13 : 15,
                      height: 1.5,
                      color: archived
                          ? theme.colorScheme.onSurface.withOpacity(0.45)
                          : isUser
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                    ),
                  ),
          ),
          if (showTimestamp && !isEmpty) ...[
            const SizedBox(height: 3),
            Padding(
              padding: EdgeInsets.only(left: isUser ? 0 : 16, right: isUser ? 16 : 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onToggleBookmark,
                  child: Text(DateFormat('HH:mm').format(message.timestamp),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
                if (onToggleBookmark != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onToggleBookmark,
                    child: Icon(
                      message.isBookmarked ? Icons.flag : Icons.flag_outlined,
                      size: 16,
                      color: message.isBookmarked
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                _ActionButton(icon: Icons.copy, tooltip: '复制', onTap: () {
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)));
                }),
                if (isUser) ...[
                  _ActionButton(icon: Icons.edit_outlined, tooltip: '编辑',
                      onTap: () => _showEditDialog(context)),
                  _ActionButton(icon: Icons.delete_outline, tooltip: '撤回',
                      onTap: () => _showRecallDialog(context)),
                ],
                if (!isUser) ...[
                  _ActionButton(icon: Icons.refresh, tooltip: '重新生成',
                      onTap: () => _showRegenerateConfirm(context)),
                  const SizedBox(width: 6),
                  Text(
                    '~${DeepSeekService.estimateTokens(message.content)} tok',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline.withOpacity(0.5), fontSize: 10),
                  ),
                ],
              ]),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(message.role == 'user' ? '编辑消息' : '编辑回复'),
        content: TextField(
          controller: controller, maxLines: 5, minLines: 3, autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final c = controller.text.trim();
              if (c.isNotEmpty) { onEdit?.call(c); Navigator.pop(ctx); }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showRecallDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤回消息'),
        content: const Text('将同时撤回你的这条消息和AI的回复。确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () { onDelete?.call(); Navigator.pop(ctx); },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('撤回'),
          ),
        ],
      ),
    );
  }

  void _showRegenerateConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新生成'),
        content: const Text('将删除当前回复，让AI根据上下文重新生成。确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () { onRegenerate?.call(); Navigator.pop(ctx); },
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, size: 14,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.6)),
      ),
    );
  }
}
