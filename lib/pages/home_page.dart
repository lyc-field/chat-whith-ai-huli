import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/conversation_provider.dart';
import '../providers/chat_provider.dart';
import '../models/conversation.dart';
import '../widgets/conversation_tile.dart';
import 'chat_page.dart';
import 'summary_management_page.dart';
import 'admin_login_page.dart';
import 'bookmark_management_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _adminTapCount = 0;
  Timer? _adminResetTimer;

  void _onTitleIconTap() {
    _adminTapCount++;
    _adminResetTimer?.cancel();
    if (_adminTapCount >= 6) {
      _adminTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginPage()),
      );
      return;
    }
    _adminResetTimer = Timer(const Duration(seconds: 3), () {
      _adminTapCount = 0;
    });
  }

  @override
  void dispose() {
    _adminResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _onTitleIconTap,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.pets, size: 20, color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: 8),
            Text('小狐爱说话',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
        centerTitle: true,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'API 设置',
            onPressed: () => _showApiKeyDialog(context),
          ),
          const SizedBox(width: 8),
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
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.2),
                          theme.colorScheme.primaryContainer.withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(Icons.forum_rounded,
                        size: 50, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 32),
                  Text('开始你的故事',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      )),
                  const SizedBox(height: 12),
                  Text('点击下方的按钮来唤醒一只小狐狸\n开启你们的独特对话吧~',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          color: theme.colorScheme.outline,
                          height: 1.5)),
                  const SizedBox(height: 48),
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
                  final newMode =
                      conv.mode == 'bookmark' ? 'summary' : 'bookmark';
                  convProvider.setConversationMode(conv.id, newMode);
                },
                onSummaries: () {
                  if (conv.mode == 'bookmark') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BookmarkManagementPage(
                                conversationId: conv.id)));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SummaryManagementPage(
                                conversationId: conv.id)));
                  }
                },
                onAvatarTap: () async {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                  );
                  if (result != null && result.files.single.path != null) {
                    await convProvider.updateConversationAvatar(
                        conv.id, result.files.single.path!);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openChat(context, null),
        elevation: 4,
        highlightElevation: 8,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text('新对话',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }

  void _openChat(BuildContext context, Conversation? conversation) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatPage(conversation: conversation)));
  }

  void _showApiKeyDialog(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    final keyCtrl = TextEditingController();
    final endpointCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    String selectedProvider = chatProvider.providerType;
    bool obscureKey = true;
    bool prefilled = false;
    // Load saved config for pre-filling fields (only once, don't overwrite user input)
    chatProvider.loadApiConfig().then((cfg) {
      if (!prefilled) {
        prefilled = true;
        keyCtrl.text = cfg['key'] ?? '';
        endpointCtrl.text = cfg['endpoint'] ?? '';
        modelCtrl.text = cfg['model'] ?? '';
      }
    });

    // Set default endpoint/model based on provider
    void applyProviderDefaults(String provider, void Function(void Function()) setState) {
      if (provider == 'deepseek') {
        endpointCtrl.text = 'https://api.deepseek.com/v1/chat/completions';
        modelCtrl.text = 'deepseek-v4-flash';
      } else if (provider == 'openai') {
        endpointCtrl.text = 'https://api.openai.com/v1/chat/completions';
        modelCtrl.text = 'gpt-4o-mini';
      } else {
        // custom: keep current text, don't overwrite
      }
      setState(() => selectedProvider = provider);
    }

    String? _inlineError;
    bool _dialogSaving = false;
    bool _dialogSaved = false;

    showDialog(
      context: context,
      builder: (outerCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(children: [
                const Text('API 设置'),
                if (_dialogSaved) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 18, color: Colors.green[600]),
                ],
              ]),
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
                      DropdownMenuItem(
                          value: 'deepseek', child: Text('DeepSeek')),
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                      DropdownMenuItem(value: 'custom', child: Text('自定义端点')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        applyProviderDefaults(v, setDialogState);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedProvider == 'custom') ...[
                    TextField(
                      controller: endpointCtrl,
                      decoration: const InputDecoration(
                        labelText: 'API 端点 URL',
                        hintText: 'https://api.example.com/v1/chat/completions',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: modelCtrl,
                      decoration: const InputDecoration(
                        labelText: '模型名称',
                        hintText: 'gpt-4o-mini',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.smart_toy, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: keyCtrl,
                    obscureText: obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureKey ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(() => obscureKey = !obscureKey),
                      ),
                    ),
                  ),
                  if (_inlineError != null) ...[
                    const SizedBox(height: 12),
                    Text(_inlineError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(outerCtx),
                    child: const Text('关闭')),
                FilledButton(
                  onPressed: _dialogSaving ? null : () async {
                    final key = keyCtrl.text.trim();
                    if (key.isEmpty) {
                      setDialogState(() => _inlineError = '请先输入 API Key');
                      return;
                    }
                    setDialogState(() {
                      _dialogSaving = true;
                      _inlineError = null;
                    });
                    try {
                      await chatProvider.setApiConfig(
                        providerType: selectedProvider,
                        key: key,
                        endpoint: endpointCtrl.text.trim().isNotEmpty
                            ? endpointCtrl.text.trim()
                            : null,
                        model: modelCtrl.text.trim().isNotEmpty
                            ? modelCtrl.text.trim()
                            : null,
                      );
                      setDialogState(() {
                        _dialogSaving = false;
                        _dialogSaved = true;
                      });
                      // Auto-clear success icon after 2 seconds
                      Future.delayed(const Duration(seconds: 2), () {
                        if (outerCtx.mounted) {
                          setDialogState(() => _dialogSaved = false);
                        }
                      });
                    } catch (_) {
                      setDialogState(() {
                        _dialogSaving = false;
                        _inlineError = '保存失败，请重试';
                      });
                    }
                  },
                  child: Text(_dialogSaving ? '保存中...' : '确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
