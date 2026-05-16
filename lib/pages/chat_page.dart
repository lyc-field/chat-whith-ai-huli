import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../models/segment_summary.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/tone_float_button.dart';
import 'persona_settings_page.dart';
import 'summary_management_page.dart';
import 'affection_log_page.dart';
import 'emotion_detail_page.dart';
import 'bookmark_management_page.dart';

class ChatPage extends StatefulWidget {
  final Conversation? conversation;
  const ChatPage({super.key, this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

enum _ItemType { message, divider, summary }

class _DisplayItem {
  final _ItemType type;
  final int? messageIndex;
  final SegmentSummary? summary;

  const _DisplayItem._(this.type, this.messageIndex, this.summary);
  factory _DisplayItem.message(int index) => _DisplayItem._(_ItemType.message, index, null);
  factory _DisplayItem.divider(SegmentSummary s) => _DisplayItem._(_ItemType.divider, null, s);
  factory _DisplayItem.summary(SegmentSummary s) => _DisplayItem._(_ItemType.summary, null, s);
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  bool _initializing = false;
  final Set<int> _expandedSegments = {};
  int? _lastPendingIndex;
  late String _title;
  bool _affectionBlink = false;
  String _mode = 'summary';

  @override
  void initState() {
    super.initState();
    final provider = context.read<ChatProvider>();
    _title = widget.conversation?.title ?? '新对话';

    _mode = widget.conversation?.mode ?? 'summary';

    if (widget.conversation != null) {
      _initializing = true;
      provider.loadConversation(widget.conversation!.id).then((_) {
        if (mounted) {
          _mode = provider.mode;
          setState(() => _initializing = false);
        }
      });
    } else {
      provider.newConversation();
    }

    provider.addListener(_onProviderChange);
  }

  void _onProviderChange() {
    final provider = context.read<ChatProvider>();
    if (provider.isPending || provider.streamingContent.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    // Auto-expand newly created pending segment.
    if (provider.showSummaryPrompt &&
        provider.pendingSummaryIndex != null &&
        provider.pendingSummaryIndex != _lastPendingIndex) {
      _lastPendingIndex = provider.pendingSummaryIndex;
      setState(() => _expandedSegments.add(provider.pendingSummaryIndex!));
    }
    if (!provider.showSummaryPrompt) {
      _lastPendingIndex = null;
    }
    // Affection blink
    if (provider.consumeAffectionChanged()) {
      setState(() => _affectionBlink = true);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _affectionBlink = false);
      });
    }
  }

  // With reverse:true, bottom is at offset 0.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollToIndex(int itemIndex, int totalItems) {
    if (!_scrollController.hasClients) return;
    final reverseIndex = (totalItems - 1 - itemIndex).clamp(0, totalItems - 1);
    final offset = (reverseIndex * 90.0)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showRuleEditor(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PersonaSettingsPage()));
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置对话'),
        content: const Text('将清空所有对话记录和总结。确定吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              context.read<ChatProvider>().resetConversation();
              _expandedSegments.clear();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('对话已重置'), duration: Duration(seconds: 1)),
              );
            },
            child: const Text('确定重置'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: _title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改对话标题'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: '输入新标题...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                final chatProvider = context.read<ChatProvider>();
                final convId = chatProvider.currentConvId;
                if (convId != null) {
                  context.read<ConversationProvider>().updateTitle(convId, newTitle);
                }
                setState(() => _title = newTitle);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // Cache display items to avoid rebuilding the full list on every streaming token.
  int _cachedMsgCount = -1;
  int _cachedSegCount = -1;
  int _cachedExpandedHash = 0;
  List<_DisplayItem> _cachedItems = const [];

  List<_DisplayItem> _buildDisplayItems(ChatProvider provider) {
    final expandedHash = Object.hashAll(_expandedSegments);
    // Only recompute when structure changes (not on streaming content updates).
    if (_cachedMsgCount == provider.messages.length &&
        _cachedSegCount == provider.segments.length &&
        _cachedExpandedHash == expandedHash) {
      return _cachedItems;
    }
    _cachedMsgCount = provider.messages.length;
    _cachedSegCount = provider.segments.length;
    _cachedExpandedHash = expandedHash;

    final items = <_DisplayItem>[];
    int? currentSegment;

    for (int i = 0; i < provider.messages.length; i++) {
      final msg = provider.messages[i];

      if (msg.segmentIndex != currentSegment) {
        if (currentSegment != null) {
          final seg = provider.getSegment(currentSegment);
          if (seg != null) items.add(_DisplayItem.summary(seg));
        }
        if (msg.segmentIndex != null) {
          final seg = provider.getSegment(msg.segmentIndex!);
          if (seg != null) items.add(_DisplayItem.divider(seg));
          currentSegment = msg.segmentIndex;
        } else {
          currentSegment = null;
        }
      }

      if (msg.segmentIndex == null ||
          _expandedSegments.contains(msg.segmentIndex)) {
        items.add(_DisplayItem.message(i));
      }
    }

    if (currentSegment != null) {
      final seg = provider.getSegment(currentSegment);
      if (seg != null) items.add(_DisplayItem.summary(seg));
    }

    _cachedItems = items;
    return items;
  }

  @override
  void dispose() {
    context.read<ChatProvider>().removeListener(_onProviderChange);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showRenameDialog(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Heart icon with affection number inside
              if (provider.affectionEnabled && provider.currentConvId != null)
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AffectionLogPage(
                        conversationId: provider.currentConvId!,
                        title: _title,
                      ),
                    ));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          _affectionBlink
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 34,
                          color: _affectionBlink
                              ? (provider.affectionIncreasing == true
                                  ? Colors.red.shade400
                                  : Colors.green.shade400)
                              : Theme.of(context).colorScheme.primary,
                        ),
                        Text(
                          '${provider.affection}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _affectionBlink
                                ? (provider.affectionIncreasing == true
                                    ? Colors.red.shade900
                                    : Colors.green.shade900)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Flexible(
                child: Text(_title, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 14, color: Colors.grey),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_mode == 'bookmark' ? Icons.flag : Icons.note_alt_outlined),
            tooltip: _mode == 'bookmark' ? '书签管理' : '查看所有总结',
            onPressed: () {
              final id = provider.currentConvId;
              if (id == null) return;
              if (_mode == 'bookmark') {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => BookmarkManagementPage(conversationId: id)));
              } else {
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => SummaryManagementPage(conversationId: id)));
              }
            },
          ),
          if (provider.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '重置对话',
              onPressed: () => _showResetDialog(context),
            ),
          IconButton(
            icon: Icon((provider.systemPrompt != null &&
                    provider.systemPrompt!.isNotEmpty)
                ? Icons.auto_awesome
                : Icons.auto_awesome_outlined),
            tooltip: '角色规则',
            onPressed: () => _showRuleEditor(context),
          ),
        ],
      ),
      body: Column(children: [
        if (provider.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(children: [
              Icon(Icons.error_outline, size: 18,
                  color: Theme.of(context).colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(provider.error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 13))),
              GestureDetector(
                onTap: () {
                  provider.newConversation();
                  _expandedSegments.clear();
                },
                child: Icon(Icons.close, size: 18,
                    color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ]),
          ),
        if (provider.showSummaryPrompt && provider.pendingSummaryIndex != null)
          _buildSummaryPromptBanner(provider),
        Expanded(
          child: Stack(
            children: [
              if (_initializing)
                const Center(child: CircularProgressIndicator())
              else if (provider.messages.isEmpty)
                Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.forum_outlined, size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('开始新对话',
                      style: Theme.of(context).textTheme.bodyLarge),
                ]))
              else
                _buildMessageList(provider),
              // Draggable tone float button
              if (provider.currentConvId != null)
                const ToneFloatButton(),
            ],
          ),
        ),
        // Quick reply bar
        if (provider.showQuickReplies &&
            provider.quickReplies.isNotEmpty &&
            !provider.isPending)
          _buildQuickReplyBar(provider),
        MessageInput(
          onSend: (text) {
            provider.sendMessage(text);
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          },
          enabled: !provider.isPending,
        ),
      ]),
    );
  }

  Widget _buildQuickReplyBar(ChatProvider provider) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(children: [
        // Safe reply
        Expanded(
          child: _quickReplyBtn(
            icon: Icons.shield_outlined,
            label: provider.quickReplies[0],
            color: theme.colorScheme.onSurfaceVariant,
            bgColor: theme.colorScheme.surfaceVariant,
            onTap: () => provider.sendQuickReply(provider.quickReplies[0]),
          ),
        ),
        const SizedBox(width: 6),
        // Novel reply
        Expanded(
          child: _quickReplyBtn(
            icon: Icons.auto_awesome,
            label: provider.quickReplies[1],
            color: theme.colorScheme.onSecondaryContainer,
            bgColor: theme.colorScheme.secondaryContainer,
            onTap: () => provider.sendQuickReply(provider.quickReplies[1]),
          ),
        ),
        const SizedBox(width: 6),
        // Continue button
        _quickReplyBtn(
          icon: Icons.skip_next,
          label: '继续',
          color: theme.colorScheme.outline,
          bgColor: Colors.transparent,
          bordered: true,
          onTap: () => provider.sendContinueCommand(),
        ),
      ]),
    );
  }

  Widget _quickReplyBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    bool bordered = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: bordered ? Border.all(color: color.withOpacity(0.4)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }

  Widget _buildSummaryPromptBanner(ChatProvider provider) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.tertiaryContainer,
      child: Row(children: [
        Icon(Icons.summarize, size: 16,
            color: theme.colorScheme.onTertiaryContainer),
        const SizedBox(width: 6),
        Expanded(
          child: Text('对话已达到20轮，建议对前5轮对话进行总结',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onTertiaryContainer)),
        ),
        TextButton(
          onPressed: () {
            final segIndex = provider.pendingSummaryIndex!;
            provider.acceptSummaryPrompt();
            setState(() => _expandedSegments.add(segIndex));
            // Find the divider position in display items and scroll there
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final items = _buildDisplayItems(provider);
              int targetIdx = 0;
              for (int i = 0; i < items.length; i++) {
                if (items[i].summary?.segmentIndex == segIndex &&
                    items[i].type == _ItemType.divider) {
                  targetIdx = i;
                  break;
                }
              }
              _scrollToIndex(targetIdx, items.length);
            });
          },
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('去总结', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () {
            provider.dismissSummaryPrompt();
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          },
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('稍后', style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _buildMessageList(ChatProvider provider) {
    final items = _buildDisplayItems(provider);
    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[items.length - 1 - i];
        switch (item.type) {
          case _ItemType.message:
            final msg = provider.messages[item.messageIndex!];
            final isAi = msg.role == 'assistant';
            return Column(
              crossAxisAlignment:
                  isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ChatBubble(
                      message: msg,
                      archived: msg.segmentIndex != null,
                      onEdit: msg.content.isNotEmpty
                          ? (c) => provider.editMessage(item.messageIndex!, c)
                          : null,
                      onDelete: () => provider.deleteMessage(item.messageIndex!),
                      onToggleBookmark: _mode == 'bookmark' &&
                              msg.role != 'system' &&
                              msg.content.isNotEmpty
                          ? () => provider.toggleBookmark(item.messageIndex!)
                          : null,
                    ),
                  ],
                ),
                if (isAi &&
                    msg.content.isNotEmpty &&
                    provider.affectionEnabled &&
                    provider.currentConvId != null) ...[
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmotionDetailPage(
                              conversationId: provider.currentConvId!,
                              title: _title,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            '对用户：${provider.emotionLabels['towards_user']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '自身：${provider.emotionLabels['self_state']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          if (provider.isSelfDestructMode)
                            Text(
                              ' ⚠',
                              style: TextStyle(fontSize: 11, color: Colors.red.shade400),
                            ),
                          const Text(' ›', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          case _ItemType.divider:
            return _buildSegmentDivider(provider, item.summary!);
          case _ItemType.summary:
            return _buildSummaryDisplay(provider, item.summary!);
        }
      },
    );
  }

  Widget _buildSegmentDivider(ChatProvider provider, SegmentSummary seg) {
    final theme = Theme.of(context);
    final isExpanded = _expandedSegments.contains(seg.segmentIndex);

    return GestureDetector(
      onTap: () {
        setState(() {
          isExpanded
              ? _expandedSegments.remove(seg.segmentIndex)
              : _expandedSegments.add(seg.segmentIndex);
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Text('第 ${seg.segmentIndex * 5 + 1}-${(seg.segmentIndex + 1) * 5} 轮对话',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
          const Text(' | ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text(isExpanded ? '折叠' : '展开',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
        ]),
      ),
    );
  }

  Widget _buildSummaryDisplay(ChatProvider provider, SegmentSummary seg) {
    final theme = Theme.of(context);
    final isEmpty = seg.content.trim().isEmpty;

    return GestureDetector(
      onTap: () => _showSummaryEditor(provider, seg),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: theme.colorScheme.tertiary.withOpacity(0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.summarize_outlined, size: 14,
              color: theme.colorScheme.tertiary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEmpty ? '点击添加总结...' : seg.content,
              style: TextStyle(
                  fontSize: 13,
                  color: isEmpty
                      ? theme.colorScheme.outline
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                  height: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.edit, size: 12, color: theme.colorScheme.outline),
        ]),
      ),
    );
  }

  void _showSummaryEditor(ChatProvider provider, SegmentSummary seg) {
    final controller = TextEditingController(text: seg.content);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('总结第 ${seg.segmentIndex * 5 + 1}-${(seg.segmentIndex + 1) * 5} 轮对话',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 10,
                minLines: 4,
                decoration: const InputDecoration(
                  hintText: '角色会以写日记的方式自动总结…你可以修改',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (seg.content.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      provider.updateSegmentSummary(seg.segmentIndex, '');
                      setState(() => _expandedSegments.remove(seg.segmentIndex));
                      Navigator.pop(ctx);
                    },
                    child: const Text('清除总结'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    provider.updateSegmentSummary(
                        seg.segmentIndex, controller.text);
                    setState(() => _expandedSegments.remove(seg.segmentIndex));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('总结已保存'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                  child: const Text('保存'),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}
