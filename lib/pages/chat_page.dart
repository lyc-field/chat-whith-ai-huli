import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../models/segment_summary.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/persona_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/message_input.dart';
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

enum _ItemType { message, divider }

class _DisplayItem {
  final _ItemType type;
  final int? messageIndex;
  final SegmentSummary? summary;

  const _DisplayItem._(this.type, this.messageIndex, this.summary);
  factory _DisplayItem.message(int index) =>
      _DisplayItem._(_ItemType.message, index, null);
  factory _DisplayItem.divider(SegmentSummary s) =>
      _DisplayItem._(_ItemType.divider, null, s);
}

class _ChatPageState extends State<ChatPage> {
  final _scrollController = ScrollController();
  bool _initializing = false;
  final Set<int> _expandedSegments = {};
  int? _lastPendingIndex;
  late String _title;
  bool _affectionBlink = false;
  String _mode = 'summary';
  String _quickReplyTone = '正常';

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
      context.read<PersonaProvider>().initPendingDefault();
    }

    provider.addListener(_onProviderChange);
    AuthService.getQuickReplyTone().then((tone) {
      if (!mounted) return;
      setState(() => _quickReplyTone = tone);
    });
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              context.read<ChatProvider>().resetConversation();
              _expandedSegments.clear();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('对话已重置'), duration: Duration(seconds: 1)),
              );
            },
            child: const Text('确定重置'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOutputLengthDialog(BuildContext context) async {
    final minC = await AuthService.getMinOutputChars();
    final maxC = await AuthService.getMaxOutputChars();
    final minCtrl =
        TextEditingController(text: minC > 0 ? minC.toString() : '');
    final maxCtrl =
        TextEditingController(text: maxC > 0 ? maxC.toString() : '');
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输出字数限制'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '最少字数',
                hintText: '0 = 不限制',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '最多字数',
                hintText: '0 = 不限制',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Text('0 表示不限制。上限会按较严格规则自动换算 token，并在本地二次截断。',
                style: Theme.of(ctx)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(ctx).colorScheme.outline)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final minVal = int.tryParse(minCtrl.text.trim()) ?? 0;
              final maxVal = int.tryParse(maxCtrl.text.trim()) ?? 0;
              if (minVal > 0 && maxVal > 0 && minVal > maxVal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('最少字数不能大于最多字数'),
                      duration: Duration(seconds: 2)),
                );
                return;
              }
              await AuthService.setMinOutputChars(minVal.clamp(0, 10000));
              await AuthService.setMaxOutputChars(maxVal.clamp(0, 10000));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                final chatProvider = context.read<ChatProvider>();
                final convId = chatProvider.currentConvId;
                if (convId != null) {
                  context
                      .read<ConversationProvider>()
                      .updateTitle(convId, newTitle);
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
    final themeProvider = context.watch<ThemeProvider>();
    final eroticTint = provider.eroticMode;
    final pinkTint = const Color(0xFFFF4FA0).withOpacity(0.08);
    const eroticAccent = Color(0xFFFF4FA0);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: eroticTint
            ? Color.alphaBlend(const Color(0xFFFF4FA0).withOpacity(0.12),
                Theme.of(context).colorScheme.surface)
            : null,
        title: GestureDetector(
          onTap: () => _showRenameDialog(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Heart icon with affection number inside
              if (provider.affectionEnabled && provider.currentConvId != null)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
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
                          size: 30,
                          color: _affectionBlink
                              ? (provider.affectionIncreasing == true
                                  ? Colors.red.shade400
                                  : Colors.green.shade400)
                              : Theme.of(context).colorScheme.primary,
                        ),
                        Text(
                          '${provider.affection}',
                          style: TextStyle(
                            fontSize: 12,
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
              const Icon(Icons.edit, size: 12, color: Colors.grey),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            iconSize: 20,
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? '切换到日间模式' : '切换到夜间模式',
            onPressed: () => themeProvider.toggleThemeMode(),
          ),
          IconButton(
            iconSize: 20,
            icon: Icon(
                _mode == 'bookmark' ? Icons.flag : Icons.note_alt_outlined),
            tooltip: _mode == 'bookmark' ? '书签管理' : '查看所有总结',
            onPressed: () {
              final id = provider.currentConvId;
              if (id == null) return;
              if (_mode == 'bookmark') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            BookmarkManagementPage(conversationId: id)));
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            SummaryManagementPage(conversationId: id)));
              }
            },
          ),
          if (provider.messages.isNotEmpty)
            IconButton(
              iconSize: 20,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '重置对话',
              onPressed: () => _showResetDialog(context),
            ),
          IconButton(
            iconSize: 20,
            icon: Icon((provider.systemPrompt != null &&
                    provider.systemPrompt!.isNotEmpty)
                ? Icons.auto_awesome
                : Icons.auto_awesome_outlined),
            tooltip: '角色规则',
            onPressed: () => _showRuleEditor(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (eroticTint)
            Positioned.fill(
              child: Container(color: pinkTint),
            ),
          // Chat background image
          if (provider.chatBackground != null &&
              provider.chatBackground!.isNotEmpty)
            Positioned.fill(
              child: Image.file(
                File(provider.chatBackground!),
                fit: BoxFit.cover,
              ),
            ),
          Column(children: [
            if (provider.error != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Row(children: [
                  Icon(Icons.error_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(provider.error!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              fontSize: 13))),
                  GestureDetector(
                    onTap: () {
                      provider.clearError();
                      _expandedSegments.clear();
                    },
                    child: Icon(Icons.close,
                        size: 18,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ]),
              ),
            if (provider.showSummaryPrompt &&
                provider.pendingSummaryIndex != null)
              _buildSummaryPromptBanner(provider),
            Expanded(
              child: _initializing
                  ? const Center(child: CircularProgressIndicator())
                  : provider.messages.isEmpty
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.forum_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('开始新对话',
                              style: Theme.of(context).textTheme.bodyLarge),
                        ]))
                      : _buildMessageList(provider),
            ),
            if (provider.quickReplies.isNotEmpty &&
                !provider.isPending &&
                provider.affectionEnabled)
              _buildQuickReplyChips(provider, eroticTint: eroticTint),
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MessageInput(
                    onSend: (text) {
                      provider.sendMessage(text);
                      _pendingInputText = null;
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToBottom());
                    },
                    enabled: !provider.isPending,
                    prefillText: _pendingInputText,
                    eroticMode: eroticTint,
                    useSafeArea: false,
                  ),
                  _buildBottomActionBar(provider,
                      eroticTint: eroticTint, eroticAccent: eroticAccent),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildQuickReplyChips(ChatProvider provider,
      {required bool eroticTint}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Container(
        decoration: eroticTint
            ? BoxDecoration(
                color: const Color(0xFFFF4FA0).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFF4FA0).withOpacity(0.2),
                ),
              )
            : null,
        padding: eroticTint
            ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
            : EdgeInsets.zero,
        child: Row(children: [
          for (int i = 0; i < provider.quickReplies.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 4,
                    right: i == provider.quickReplies.length - 1 ? 0 : 4),
                child: _QuickReplyChip(
                  index: i,
                  label: provider.quickReplies[i],
                  eroticTint: eroticTint,
                  onTap: (text) => _fillInput(text),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _fillInput(String text) {
    context.read<ChatProvider>().consumeQuickReply(0);
    _pendingInputText = text;
    setState(() {});
  }

  Future<void> _pickTone() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in AuthService.quickReplyTones)
                  ListTile(
                    leading: Icon(
                      t == '下流'
                          ? Icons.whatshot
                          : t == '优雅'
                              ? Icons.auto_awesome
                              : Icons.chat_bubble_outline,
                    ),
                    title: Text(t),
                    trailing: _quickReplyTone == t
                        ? Icon(Icons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, t),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || picked == _quickReplyTone) return;
    await AuthService.setQuickReplyTone(picked);
    if (!mounted) return;
    setState(() => _quickReplyTone = picked);
  }

  Future<void> _pickDeepSeekModel() async {
    final provider = context.read<ChatProvider>();
    if (provider.providerType != 'deepseek') return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final currentModel = provider.deepSeekModel;
        return AlertDialog(
          title: const Text('选择 DeepSeek 模型'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'deepseek-v4-flash',
                groupValue: currentModel,
                title: const Text('v4-flash'),
                subtitle: const Text('速度更快，适合日常聊天'),
                onChanged: (value) => Navigator.pop(ctx, value),
              ),
              RadioListTile<String>(
                value: 'deepseek-v4-pro',
                groupValue: currentModel,
                title: const Text('v4-pro'),
                subtitle: const Text('能力更强，适合更细腻的回复'),
                onChanged: (value) => Navigator.pop(ctx, value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (selected == null || selected == provider.deepSeekModel) return;
    await provider.setDeepSeekModel(selected);
    if (!mounted) return;
    final label = selected == 'deepseek-v4-pro' ? 'v4-pro' : 'v4-flash';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换到 $label，当前上下文未重置'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Widget _buildBottomActionBar(ChatProvider provider,
      {required bool eroticTint, required Color eroticAccent}) {
    final theme = Theme.of(context);
    final canContinue = provider.currentConvId != null && !provider.isPending;
    final bg = eroticTint
        ? Color.alphaBlend(
            eroticAccent.withOpacity(0.10),
            theme.colorScheme.surface,
          )
        : theme.colorScheme.surface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: eroticTint
                ? eroticAccent.withOpacity(0.22)
                : theme.colorScheme.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: IconButton.filled(
                onPressed: provider.providerType == 'deepseek'
                    ? _pickDeepSeekModel
                    : null,
                tooltip: provider.providerType == 'deepseek'
                    ? 'DeepSeek 模型：${provider.isDeepSeekPro ? 'v4-pro' : 'v4-flash'}'
                    : '当前提供商不支持模型切换',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 34, height: 34),
                icon: Icon(
                  provider.isDeepSeekPro ? Icons.cloud : Icons.cloud_outlined,
                  size: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: IconButton.filledTonal(
                onPressed: _pickTone,
                tooltip: '快捷回复语气：$_quickReplyTone',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 34, height: 34),
                icon: Icon(
                  _quickReplyTone == '下流'
                      ? Icons.whatshot
                      : _quickReplyTone == '优雅'
                          ? Icons.auto_awesome
                          : Icons.chat_bubble_outline,
                  size: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: IconButton.filled(
                onPressed:
                    canContinue ? () => provider.sendContinueCommand() : null,
                tooltip: '继续回复',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 34, height: 34),
                icon: const Icon(Icons.fast_forward, size: 16),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: IconButton.filledTonal(
                onPressed: () => _showOutputLengthDialog(context),
                tooltip: '输出字数限制',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints.tightFor(width: 34, height: 34),
                icon: const Icon(Icons.tune, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _pendingInputText;

  Widget _buildSummaryPromptBanner(ChatProvider provider) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.tertiaryContainer,
      child: Row(children: [
        Icon(Icons.summarize,
            size: 16, color: theme.colorScheme.onTertiaryContainer),
        const SizedBox(width: 6),
        Expanded(
          child: Text('对话已达到20轮，建议对前5轮对话进行总结',
              style: TextStyle(
                  fontSize: 12, color: theme.colorScheme.onTertiaryContainer)),
        ),
        TextButton(
          onPressed: () {
            provider.acceptSummaryPrompt();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SummaryManagementPage(
                  conversationId: provider.currentConvId!,
                ),
              ),
            );
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
                      onEdit: isAi ||
                              msg.segmentIndex != null ||
                              msg.content.isEmpty
                          ? null
                          : (c) => provider.editMessage(item.messageIndex!, c),
                      onDelete: isAi ||
                              msg.segmentIndex != null ||
                              provider.remainingRecalls <= 0
                          ? null
                          : () => provider.deleteMessage(item.messageIndex!),
                      onRegenerate: !isAi ||
                              msg.segmentIndex != null ||
                              msg.content.isEmpty
                          ? null
                          : () =>
                              provider.regenerateResponse(item.messageIndex!),
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
                              style: TextStyle(
                                  fontSize: 11, color: Colors.red.shade400),
                            ),
                          const Text(' ›',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          case _ItemType.divider:
            return _buildSegmentDivider(provider, item.summary!);
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
          Text('第 ${seg.effectiveRoundStart}-${seg.effectiveRoundEnd} 轮对话',
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
          border:
              Border.all(color: theme.colorScheme.tertiary.withOpacity(0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.summarize_outlined,
              size: 14, color: theme.colorScheme.tertiary.withOpacity(0.7)),
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
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  '总结第 ${seg.effectiveRoundStart}-${seg.effectiveRoundEnd} 轮对话',
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
                      setState(
                          () => _expandedSegments.remove(seg.segmentIndex));
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

/// Quick reply chip: tap to fill input, long-press to preview full content.
class _QuickReplyChip extends StatelessWidget {
  final int index;
  final String label;
  final bool eroticTint;
  final ValueChanged<String> onTap;

  const _QuickReplyChip({
    required this.index,
    required this.label,
    required this.eroticTint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFirst = index == 0;
    const eroticColor = Color(0xFFFF4FA0);
    return GestureDetector(
      onTap: () => onTap(label),
      onLongPress: () => _showPreview(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: eroticTint
              ? Color.alphaBlend(
                  eroticColor.withOpacity(isFirst ? 0.16 : 0.22),
                  isFirst
                      ? theme.colorScheme.surfaceVariant
                      : theme.colorScheme.secondaryContainer,
                )
              : isFirst
                  ? theme.colorScheme.surfaceVariant
                  : theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: eroticTint
              ? Border.all(color: eroticColor.withOpacity(0.28))
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isFirst ? Icons.shield_outlined : Icons.auto_awesome,
              size: 14,
              color: isFirst
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: isFirst
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }

  void _showPreview(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child:
                Text(label, style: const TextStyle(fontSize: 15, height: 1.6)),
          ),
        ),
      ),
    );
  }
}
