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
    return Scaffold(
      appBar: AppBar(
        title: const Text('小狐爱说话'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded),
            tooltip: '设置 API Key',
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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_outlined, size: 64,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text('没有对话记录', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 8),
                const Text('点击右下角按钮开始新对话'),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openChat(context, null),
        child: const Icon(Icons.add_comment_rounded),
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
                    onPressed: () => Navigator.pop(outerCtx),
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
                      // Hidden trigger: 6 taps on "确定" with empty key within 3s
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
