import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../models/conversation.dart';
import '../widgets/conversation_tile.dart';
import 'chat_page.dart';
import 'summary_management_page.dart';
import 'admin_login_page.dart';
import 'bookmark_management_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('小狐爱说话', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'API 设置',
            onPressed: () => _showApiKeyDialog(context),
          ),
        ],
      ),
      body: Consumer<ConversationProvider>(
        builder: (context, convProvider, _) {
          if (convProvider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (convProvider.conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 40,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text('开始你的故事',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('点击下方按钮，创建新对话',
                      style: TextStyle(fontSize: 14, color: theme.colorScheme.outline)),
                ]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            itemCount: convProvider.conversations.length,
            itemBuilder: (_, i) {
              final conv = convProvider.conversations[i];
              return ConversationTile(
                conversation: conv,
                onTap: () => _openChat(context, conv),
                onDelete: () => convProvider.deleteConversation(conv.id),
                onToggleMode: () {
                  final newMode = conv.mode == 'bookmark' ? 'summary' : 'bookmark';
                  convProvider.setConversationMode(conv.id, newMode);
                },
                onSummaries: () {
                  if (conv.mode == 'bookmark') {
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) =>
                                BookmarkManagementPage(conversationId: conv.id)));
                  } else {
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) =>
                                SummaryManagementPage(conversationId: conv.id)));
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChat(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新对话'),
      ),
    );
  }

  void _openChat(BuildContext context, Conversation? conversation) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatPage(conversation: conversation)));
  }

  void _showApiKeyDialog(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final keyCtrl = TextEditingController();
    String selectedProvider = chatProvider.providerType;
    int tapCount = 0;
    Timer? resetTimer;

    showDialog(
      context: context,
      builder: (outerCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('API 设置'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedProvider,
                    decoration: const InputDecoration(
                      labelText: '模型供应商',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cloud, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek')),
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                      DropdownMenuItem(value: 'custom', child: Text('自定义端点')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedProvider = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key, size: 20),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      resetTimer?.cancel();
                      Navigator.pop(outerCtx);
                    },
                    child: const Text('取消')),
                FilledButton(
                  onPressed: () async {
                    final key = keyCtrl.text.trim();
                    if (key.isNotEmpty) {
                      await chatProvider.setApiConfig(
                        providerType: selectedProvider,
                        key: key,
                      );
                      if (outerCtx.mounted) Navigator.pop(outerCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('API 已设置')),
                        );
                      }
                    } else {
                      tapCount++;
                      if (tapCount >= 6) {
                        Navigator.pop(outerCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AdminLoginPage()),
                        );
                        return;
                      }
                      resetTimer?.cancel();
                      resetTimer = Timer(const Duration(seconds: 3), () {
                        tapCount = 0;
                      });
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
