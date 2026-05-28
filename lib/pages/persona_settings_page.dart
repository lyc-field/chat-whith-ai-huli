import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/ai_persona.dart';
import '../providers/chat_provider.dart';
import '../providers/persona_provider.dart';
import '../services/persona_io.dart';
import 'export_persona_dialog.dart';

class PersonaSettingsPage extends StatefulWidget {
  const PersonaSettingsPage({super.key});

  @override
  State<PersonaSettingsPage> createState() => _PersonaSettingsPageState();
}

class _PersonaSettingsPageState extends State<PersonaSettingsPage> {
  late final TextEditingController _userController;
  late final TextEditingController _worldBgController;
  late final TextEditingController _openingLineCtrl;
  int _affectionSlider = 30;

  // AI persona field controllers — recreated when persona switches
  late TextEditingController _nameCtrl;
  late TextEditingController _identityCtrl;
  late TextEditingController _personalityCtrl;
  late TextEditingController _appearanceCtrl;
  late TextEditingController _notesCtrl;
  late final TextEditingController _legacyPromptCtrl;

  @override
  void initState() {
    super.initState();
    final chat = context.read<ChatProvider>();
    _userController = TextEditingController(text: chat.userPersona ?? '');
    _worldBgController = TextEditingController(text: chat.worldBackground ?? '');
    _openingLineCtrl = TextEditingController(text: chat.openingLine ?? '');
    _legacyPromptCtrl = TextEditingController(text: chat.systemPrompt ?? '');
    _affectionSlider = chat.affection.clamp(15, 50);

    final pp = context.read<PersonaProvider>();
    _initPersonaControllers(pp.currentPersona);
  }

  void _initPersonaControllers(AIPersona? p) {
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _identityCtrl = TextEditingController(text: p?.identity ?? '');
    _personalityCtrl = TextEditingController(text: p?.personality ?? '');
    _appearanceCtrl = TextEditingController(text: p?.appearance ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
  }

  void _disposePersonaControllers() {
    _nameCtrl.dispose();
    _identityCtrl.dispose();
    _personalityCtrl.dispose();
    _appearanceCtrl.dispose();
    _notesCtrl.dispose();
  }

  // Call when any AI persona field changes — debounced auto-save
  void _onPersonaFieldChanged(PersonaProvider pp) {
    final p = pp.currentPersona;
    if (p == null) return;
    p.name = _nameCtrl.text.trim();
    p.identity = _identityCtrl.text.trim();
    p.personality = _personalityCtrl.text.trim();
    p.appearance = _appearanceCtrl.text.trim();
    p.notes = _notesCtrl.text.trim();
    pp.autoSave(p);
  }

  void _switchToPersona(PersonaProvider pp, int index) {
    if (index == pp.currentIndex) return;
    final cp = pp.currentPersona;
    if (cp != null) {
      cp.name = _nameCtrl.text.trim();
      cp.identity = _identityCtrl.text.trim();
      cp.personality = _personalityCtrl.text.trim();
      cp.appearance = _appearanceCtrl.text.trim();
      cp.notes = _notesCtrl.text.trim();
      pp.saveImmediately(cp);
    }
    pp.selectPersona(index);
    _disposePersonaControllers();
    _initPersonaControllers(pp.currentPersona);
    setState(() {});
  }

  Future<void> _save() async {
    final chat = context.read<ChatProvider>();
    final pp = context.read<PersonaProvider>();
    final isLegacy = pp.personas.isEmpty;

    if (isLegacy) {
      await chat.setSystemPrompt(_legacyPromptCtrl.text);
    } else {
      final cp = pp.currentPersona;
      if (cp != null) {
        cp.name = _nameCtrl.text.trim();
        cp.identity = _identityCtrl.text.trim();
        cp.personality = _personalityCtrl.text.trim();
        cp.appearance = _appearanceCtrl.text.trim();
        cp.notes = _notesCtrl.text.trim();
        await pp.saveImmediately(cp);
        final prompt = cp.buildPrompt();
        await chat.setSystemPrompt(prompt);
      }
    }

    // Allow affection adjustment as long as no user messages have been sent
    if (chat.messages.where((m) => m.role == 'user').isEmpty) {
      chat.setInitialAffection(_affectionSlider);
    }
    // OpeningLine must be set before userPersona/worldBackground because
    // it may create the conversation, which the latter two then persist to.
    await chat.setOpeningLine(_openingLineCtrl.text);
    await chat.setUserPersona(_userController.text);
    await chat.setWorldBackground(_worldBgController.text);
    if (chat.isNewFormat) await chat.syncPersonaState();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设定已保存'), duration: Duration(seconds: 1)),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _convertToNewFormat(PersonaProvider pp) async {
    final oldPrompt = _legacyPromptCtrl.text.trim();
    if (oldPrompt.isEmpty) {
      await pp.createPersona('默认角色');
    } else {
      await pp.createPersona('默认角色');
      final cp = pp.currentPersona;
      if (cp != null) {
        final firstLine = oldPrompt.split('\n').first.trim();
        if (firstLine.length <= 30) {
          cp.name = firstLine;
        } else {
          cp.name = firstLine.substring(0, 30);
        }
        cp.personality = oldPrompt;
        await pp.saveImmediately(cp);
      }
    }
    _disposePersonaControllers();
    _initPersonaControllers(pp.currentPersona);
    if (mounted) setState(() {});
  }

  Future<void> _deleteCurrentPersona(PersonaProvider pp) async {
    final cp = pp.currentPersona;
    if (cp == null || pp.personas.length <= 1) return;
    await pp.deletePersona(cp.id);
    _disposePersonaControllers();
    _initPersonaControllers(pp.currentPersona);
    if (mounted) setState(() {});
  }

  Future<void> _createNewPersona(PersonaProvider pp) async {
    final cp = pp.currentPersona;
    if (cp != null) {
      cp.name = _nameCtrl.text.trim();
      cp.identity = _identityCtrl.text.trim();
      cp.personality = _personalityCtrl.text.trim();
      cp.appearance = _appearanceCtrl.text.trim();
      cp.notes = _notesCtrl.text.trim();
      await pp.saveImmediately(cp);
    }
    await pp.createPersona('新角色');
    _disposePersonaControllers();
    _initPersonaControllers(pp.currentPersona);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameCtrl.selection = TextSelection(
          baseOffset: 0, extentOffset: _nameCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _worldBgController.dispose();
    _openingLineCtrl.dispose();
    _legacyPromptCtrl.dispose();
    _disposePersonaControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = context.watch<ChatProvider>();
    final pp = context.watch<PersonaProvider>();

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
          if (pp.personas.isEmpty) ...[
            // ── 旧版格式（单文本框） ──
            Row(children: [
              Text('AI 角色人设', style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('旧版', style: TextStyle(fontSize: 11, color: theme.colorScheme.tertiary)),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _legacyPromptCtrl,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: '设定 AI 的角色和行为规则…\n例如：你是一只可爱的小狐狸，名字叫眠眠…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _convertToNewFormat(pp),
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('转换为新版人设'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
              ),
            ),
          ] else ...[
            // ── 新版格式（结构化表单） ──
            Text('AI 角色人设', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),

            _buildField('角色名称', _nameCtrl, maxLines: 1,
                hint: '例如：眠眠', onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('身份信息', _identityCtrl, maxLines: 2,
                hint: '例如：生活在神社里的百年狐妖，神社的守护者...',
                onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('性格习惯', _personalityCtrl, maxLines: 3,
                hint: '例如：温柔善良，偶尔傲娇，喜欢撒娇，说话时尾巴会摇来摇去...',
                onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('外观外貌', _appearanceCtrl, maxLines: 2,
                hint: '例如：橙色狐狸耳朵，毛茸茸的大尾巴，穿着白色和服，紫色眼睛...',
                onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('补充信息', _notesCtrl, maxLines: 3,
                hint: '例如：喜欢晒太阳，讨厌下雨天，一直等待有缘人的到来...',
                onChanged: () => _onPersonaFieldChanged(pp)),

          ],

          const Divider(height: 32),

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

          // ── 开场白 ──
          Text('开场白', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('开始聊天时由系统自动输出到聊天界面，在用户发送第一条消息前显示',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          TextField(
            controller: _openingLineCtrl,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: '例如：你推开神社的门，看到一只狐狸正趴在台阶上晒太阳...\n留空则不注入',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // ── 世界背景 ──
          Text('世界背景', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('描述故事发生的世界设定，例如环境、规则、时代等',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          TextField(
            controller: _worldBgController,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: '例如：在一个充满魔法与蒸汽机械的大陆上…\n留空则不注入',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // ── 聊天背景 ──
          Text('聊天背景', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('从相册选择一张图片作为聊天界面的背景',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Row(children: [
            if (chat.chatBackground != null && chat.chatBackground!.isNotEmpty)
              Container(
                width: 72,
                height: 72,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  image: DecorationImage(
                    image: FileImage(File(chat.chatBackground!)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _pickChatBackground,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(chat.chatBackground != null ? '更换背景' : '选择图片'),
            ),
            if (chat.chatBackground != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => chat.setChatBackground(null),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: '清除背景',
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text('建议使用长方形照片，竖屏效果最佳',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline.withOpacity(0.7))),
          const SizedBox(height: 24),

          // ── 初始好感度 ──
          if (chat.affectionEnabled) ...[
            if (chat.messages.where((m) => m.role == 'user').isEmpty) ...[
              Text('初始好感度', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text('范围 15~50，保存后由系统根据对话内容自动调整',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _affectionSlider.toDouble(),
                    min: 15,
                    max: 50,
                    divisions: 35,
                    label: '$_affectionSlider',
                    onChanged: (v) =>
                        setState(() => _affectionSlider = v.round()),
                  ),
                ),
                SizedBox(
                    width: 40,
                    child: Text('$_affectionSlider',
                        style: theme.textTheme.bodySmall)),
              ]),
            ] else ...[
              Text('当前好感度：${chat.affection}（由系统自动管理）',
                  style: TextStyle(color: theme.colorScheme.outline)),
            ],
          ],

          const SizedBox(height: 16),
          // ── 导出 / 导入（仅新版人设可用） ──
          if (pp.personas.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showExportDialog,
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('导出角色包'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _importFile,
                  icon: const Icon(Icons.file_open, size: 18),
                  label: const Text('导入角色包'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xhp', 'json'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await PersonaIO.readJsonFile(file.path!);
      } else {
        return;
      }

      final parsed = PersonaIO.parseImportJson(content);
      if (!mounted) return;

      if (parsed.error != null) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 28),
            title: const Text('导入失败'),
            content: Text(parsed.error!),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
            ],
          ),
        );
        return;
      }

      final pp = context.read<PersonaProvider>();

      final cp = pp.currentPersona;
      if (cp != null) {
        cp.name = _nameCtrl.text.trim();
        cp.identity = _identityCtrl.text.trim();
        cp.personality = _personalityCtrl.text.trim();
        cp.appearance = _appearanceCtrl.text.trim();
        cp.notes = _notesCtrl.text.trim();
        await pp.saveImmediately(cp);
      }

      for (final p in parsed.personas) {
        await pp.importPersona(p);
      }

      // Clean up empty placeholder personas (name='默认角色' + all content fields empty)
      // so the imported persona becomes the only one and survives app restart.
      if (parsed.personas.isNotEmpty) {
        final toRemove = <String>[];
        for (final p in pp.personas) {
          final isEmpty = p.identity.trim().isEmpty &&
              p.personality.trim().isEmpty &&
              p.appearance.trim().isEmpty &&
              p.notes.trim().isEmpty &&
              (p.name.trim().isEmpty || p.name.trim() == '默认角色');
          if (isEmpty) toRemove.add(p.id);
        }
        // Only clean up if some personas with content will remain
        if (toRemove.length < pp.personas.length) {
          for (final id in toRemove) {
            await pp.removePersona(id);
          }
        }
      }

      if (parsed.userPersona != null && parsed.userPersona!.isNotEmpty) {
        _userController.text = parsed.userPersona!;
      }
      if (parsed.worldBackground != null && parsed.worldBackground!.isNotEmpty) {
        _worldBgController.text = parsed.worldBackground!;
      }
      if (parsed.openingLine != null && parsed.openingLine!.isNotEmpty) {
        _openingLineCtrl.text = parsed.openingLine!;
      }

      if (parsed.personas.isNotEmpty) {
        pp.selectPersona(pp.personas.length - parsed.personas.length);
      }

      _disposePersonaControllers();
      _initPersonaControllers(pp.currentPersona);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导入 ${parsed.personas.length} 个角色'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 28),
            title: const Text('导入失败'),
            content: const Text('无法读取文件，请确认文件格式正确'),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _pickChatBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty || result.files.first.path == null) return;
      final chat = context.read<ChatProvider>();
      await chat.setChatBackground(result.files.first.path!);
      setState(() {});
    } catch (_) {}
  }

  void _showExportDialog() {
    showDialog<String>(
      context: context,
      builder: (_) => const ExportPersonaDialog(),
    ).then((json) {
      if (json == null || json.isEmpty || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFileNameDialog(json);
      });
    });
  }

  void _showFileNameDialog(String json) {
    final nameCtrl = TextEditingController(text: '角色包');
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置文件名'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: '输入文件名...',
            suffixText: '.json',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((fileName) {
      final finalName = (fileName != null && fileName.isNotEmpty) ? fileName : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        if (finalName == null || !mounted) return;
        PersonaIO.shareJson(json: json, fileName: finalName);
      });
    });
  }

  Widget _buildField(String label, TextEditingController controller,
      {int maxLines = 1, String? hint, VoidCallback? onChanged}) {
    Widget field = TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines > 1 ? null : 1,
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: field,
    );
  }
}
