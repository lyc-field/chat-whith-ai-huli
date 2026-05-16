import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/auth_service.dart';

/// Full-screen persona settings page.
/// Replaces the old half-screen bottom sheet.
class PersonaSettingsPage extends StatefulWidget {
  const PersonaSettingsPage({super.key});

  @override
  State<PersonaSettingsPage> createState() => _PersonaSettingsPageState();
}

class _PersonaSettingsPageState extends State<PersonaSettingsPage> {
  late final TextEditingController _aiController;
  late final TextEditingController _userController;
  int _affectionSlider = 30;
  String? _globalRules;
  bool _showGlobalRules = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ChatProvider>();
    _aiController = TextEditingController(text: provider.systemPrompt ?? '');
    _userController = TextEditingController(text: provider.userPersona ?? '');
    _affectionSlider = provider.affection.clamp(-15, 50);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final rules = await AuthService.getGlobalPrompt();
    if (mounted) {
      setState(() => _globalRules = rules);
    }
  }

  Future<void> _importPersona() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final file = result.files.first;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) return;
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      var persona = json['persona'] as String? ?? '';
      var userPersona = json['user_persona'] as String?;
      var name = json['name'] as String?;
      var aff = json['initial_affection'] as int?;
      if (persona.isEmpty) {
        final data = json['data'] as Map<String, dynamic>?;
        final prompts = data?['prompts'] as Map<String, dynamic>?;
        if (prompts != null && prompts.isNotEmpty) {
          final firstKey = prompts.keys.first;
          final variant = prompts[firstKey] as Map<String, dynamic>?;
          final vdata = variant?['data'] as Map<String, dynamic>?;
          if (vdata != null) {
            name ??= vdata['name'] as String?;
            final desc = vdata['description'] as String? ?? '';
            final personality = vdata['personality'] as String? ?? '';
            final scenario = vdata['scenario'] as String? ?? '';
            final sb = StringBuffer();
            if (desc.isNotEmpty) sb.writeln(desc);
            if (personality.isNotEmpty) {
              if (sb.isNotEmpty) sb.writeln();
              sb.writeln('【性格】$personality');
            }
            if (scenario.isNotEmpty) {
              if (sb.isNotEmpty) sb.writeln();
              sb.writeln('【背景】$scenario');
            }
            persona = sb.toString().trim();
          }
        }
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(name != null ? '导入「$name」' : '导入成功',
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('人设内容预览：',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 200),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: Text(persona.isNotEmpty ? persona : '(空)',
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认使用'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        setState(() {
          if (persona.isNotEmpty) _aiController.text = persona;
          if (userPersona != null && userPersona.isNotEmpty) _userController.text = userPersona;
          if (aff != null) _affectionSlider = aff.clamp(-15, 50);
        });
      }
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.error, color: Colors.red, size: 22),
              const SizedBox(width: 8),
              const Text('导入失败'),
            ]),
            content: const Text('JSON 格式错误，请检查文件内容'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final provider = context.read<ChatProvider>();
    if (provider.systemPrompt == null || provider.systemPrompt!.isEmpty) {
      provider.setInitialAffection(_affectionSlider);
    }
    await provider.setSystemPrompt(_aiController.text);
    await provider.setUserPersona(_userController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设定已保存'), duration: Duration(seconds: 1)),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _aiController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    final hasGlobal = _globalRules != null && _globalRules!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('角色设定'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── AI 角色人设 ──
          Text('AI 角色人设', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _aiController,
            maxLines: 6,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: '设定 AI 的角色和行为规则…\n例如：你是一只可爱的小狐狸，名字叫眠眠…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // ── 用户人设 ──
          Text('用户人设', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('描述和 AI 对话的人是谁，AI 会根据这个调整态度',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          TextField(
            controller: _userController,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: '例如：一位迷路的旅人，看起来很疲惫…\n留空则不注入',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // ── 初始好感度 ──
          if (provider.systemPrompt == null || provider.systemPrompt!.isEmpty) ...[
            if (provider.affectionEnabled) ...[
              Text('初始好感度', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _affectionSlider.toDouble(),
                    min: -15, max: 50, divisions: 65,
                    label: '$_affectionSlider',
                    onChanged: (v) => setState(() => _affectionSlider = v.round()),
                  ),
                ),
                SizedBox(width: 40, child: Text('$_affectionSlider',
                    style: theme.textTheme.bodySmall)),
              ]),
            ],
          ] else ...[
            if (provider.affectionEnabled)
              Text('当前好感度：${provider.affection}（由系统自动管理）',
                  style: TextStyle(color: theme.colorScheme.outline)),
          ],

          const SizedBox(height: 28),

          // ── JSON 导入 ──
          OutlinedButton.icon(
            onPressed: _importPersona,
            icon: const Icon(Icons.file_open, size: 18),
            label: const Text('导入 JSON 人设'),
          ),

          // ── 管理员安全规则 ──
          if (hasGlobal) ...[
            const SizedBox(height: 24),
            InkWell(
              onTap: () => setState(() => _showGlobalRules = !_showGlobalRules),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.gpp_maybe, size: 18,
                      color: theme.colorScheme.tertiary),
                  const SizedBox(width: 8),
                  Text('管理员安全规则',
                      style: TextStyle(color: theme.colorScheme.tertiary)),
                  const Spacer(),
                  Icon(_showGlobalRules ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.tertiary),
                ]),
              ),
            ),
            if (_showGlobalRules) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_globalRules!, style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5)),
              ),
            ],
          ],

          const SizedBox(height: 40), // room for future fields
        ],
      ),
    );
  }
}
