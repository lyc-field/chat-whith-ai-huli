import 'dart:convert';
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
  int _affectionSlider = 30;

  // AI persona field controllers — recreated when persona switches
  late TextEditingController _nameCtrl;
  late TextEditingController _personalityCtrl;
  late TextEditingController _habitsCtrl;
  late TextEditingController _appearanceCtrl;
  late TextEditingController _backgroundCtrl;
  late TextEditingController _openingLineCtrl;
  late final TextEditingController _legacyPromptCtrl;

  @override
  void initState() {
    super.initState();
    final chat = context.read<ChatProvider>();
    _userController = TextEditingController(text: chat.userPersona ?? '');
    _worldBgController = TextEditingController(text: chat.worldBackground ?? '');
    _legacyPromptCtrl = TextEditingController(text: chat.systemPrompt ?? '');
    _affectionSlider = chat.affection.clamp(-15, 50);

    final pp = context.read<PersonaProvider>();
    _initPersonaControllers(pp.currentPersona);
  }

  void _initPersonaControllers(AIPersona? p) {
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _personalityCtrl = TextEditingController(text: p?.personality ?? '');
    _habitsCtrl = TextEditingController(text: p?.habits ?? '');
    _appearanceCtrl = TextEditingController(text: p?.appearance ?? '');
    _backgroundCtrl = TextEditingController(text: p?.background ?? '');
    _openingLineCtrl = TextEditingController(text: p?.openingLine ?? '');
  }

  void _disposePersonaControllers() {
    _nameCtrl.dispose();
    _personalityCtrl.dispose();
    _habitsCtrl.dispose();
    _appearanceCtrl.dispose();
    _backgroundCtrl.dispose();
    _openingLineCtrl.dispose();
  }

  // Call when any AI persona field changes — debounced auto-save
  void _onPersonaFieldChanged(PersonaProvider pp) {
    final p = pp.currentPersona;
    if (p == null) return;
    p.name = _nameCtrl.text.trim();
    p.personality = _personalityCtrl.text.trim();
    p.habits = _habitsCtrl.text.trim();
    p.appearance = _appearanceCtrl.text.trim();
    p.background = _backgroundCtrl.text.trim();
    p.openingLine = _openingLineCtrl.text.trim();
    pp.autoSave(p);
  }

  void _switchToPersona(PersonaProvider pp, int index) {
    if (index == pp.currentIndex) return;
    // Flush pending save for current persona
    final cp = pp.currentPersona;
    if (cp != null) {
      cp.name = _nameCtrl.text.trim();
      cp.personality = _personalityCtrl.text.trim();
      cp.habits = _habitsCtrl.text.trim();
      cp.appearance = _appearanceCtrl.text.trim();
      cp.background = _backgroundCtrl.text.trim();
      cp.openingLine = _openingLineCtrl.text.trim();
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
      // Old format: save raw system prompt
      await chat.setSystemPrompt(_legacyPromptCtrl.text);
    } else {
      // New format: save persona fields and build system prompt
      final cp = pp.currentPersona;
      if (cp != null) {
        cp.name = _nameCtrl.text.trim();
        cp.personality = _personalityCtrl.text.trim();
        cp.habits = _habitsCtrl.text.trim();
        cp.appearance = _appearanceCtrl.text.trim();
        cp.background = _backgroundCtrl.text.trim();
        cp.openingLine = _openingLineCtrl.text.trim();
        await pp.saveImmediately(cp);
        final prompt = cp.buildPrompt();
        await chat.setSystemPrompt(prompt);
      }
    }

    if (chat.systemPrompt == null || chat.systemPrompt!.isEmpty) {
      chat.setInitialAffection(_affectionSlider);
    }
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
      // Just create a blank default persona
      await pp.createPersona('默认角色');
    } else {
      // Create a persona with the old prompt as personality
      await pp.createPersona('默认角色');
      final cp = pp.currentPersona;
      if (cp != null) {
        // Use first line as name if short enough
        final firstLine = oldPrompt.split('\n').first.trim();
        if (firstLine.length <= 30) {
          cp.name = firstLine;
        } else {
          cp.name = firstLine.substring(0, 30);
        }
        cp.background = oldPrompt;
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
    // Flush current persona before creating new one
    final cp = pp.currentPersona;
    if (cp != null) {
      cp.name = _nameCtrl.text.trim();
      cp.personality = _personalityCtrl.text.trim();
      cp.habits = _habitsCtrl.text.trim();
      cp.appearance = _appearanceCtrl.text.trim();
      cp.background = _backgroundCtrl.text.trim();
      cp.openingLine = _openingLineCtrl.text.trim();
      await pp.saveImmediately(cp);
    }
    await pp.createPersona('新角色');
    _disposePersonaControllers();
    _initPersonaControllers(pp.currentPersona);
    setState(() {});
    // Auto-focus the name field so user can rename immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameCtrl.selection = TextSelection(
          baseOffset: 0, extentOffset: _nameCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _worldBgController.dispose();
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
            const SizedBox(height: 8),

            // Persona selector chips
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pp.personas.length + 1,
                itemBuilder: (_, i) {
                  if (i == pp.personas.length) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('新建'),
                        onPressed: () => _createNewPersona(pp),
                      ),
                    );
                  }
                  final isSelected = i == pp.currentIndex;
                  final p = pp.personas[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p.name.isNotEmpty ? p.name : '未命名',
                          style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w400)),
                      selected: isSelected,
                      onSelected: (_) => _switchToPersona(pp, i),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            _buildField('角色名称', _nameCtrl, maxLines: 1,
                hint: '例如：眠眠', onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('性格', _personalityCtrl, maxLines: 2,
                hint: '例如：温柔善良，偶尔傲娇，喜欢撒娇...',
                onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('习惯', _habitsCtrl, maxLines: 2,
                hint: '例如：喜欢蹭人的手，说话时尾巴会摇来摇去...',
                onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('外观', _appearanceCtrl, maxLines: 2,
                hint: '例如：橙色狐狸耳朵，毛茸茸的大尾巴，穿着和服...',
                onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('背景', _backgroundCtrl, maxLines: 3,
                hint: '例如：生活在神社里的百年狐妖，一直在等待一个有缘人...',
                onChanged: () => _onPersonaFieldChanged(pp)),
            _buildField('开场白', _openingLineCtrl, maxLines: 2,
                hint: '例如：你推开神社的门，看到一只狐狸正趴在台阶上晒太阳...',
                onChanged: () => _onPersonaFieldChanged(pp)),

            if (pp.personas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _deleteCurrentPersona(pp),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('删除当前角色'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                ),
              ),
            ],
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

          // ── 初始好感度 ──
          if (chat.systemPrompt == null || chat.systemPrompt!.isEmpty) ...[
            if (chat.affectionEnabled) ...[
              Text('初始好感度', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _affectionSlider.toDouble(),
                    min: -15,
                    max: 50,
                    divisions: 65,
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
            ],
          ] else ...[
            if (chat.affectionEnabled)
              Text('当前好感度：${chat.affection}（由系统自动管理）',
                  style: TextStyle(color: theme.colorScheme.outline)),
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
        allowedExtensions: ['json'],
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

      // Flush current persona before importing
      final cp = pp.currentPersona;
      if (cp != null) {
        cp.name = _nameCtrl.text.trim();
        cp.personality = _personalityCtrl.text.trim();
        cp.habits = _habitsCtrl.text.trim();
        cp.appearance = _appearanceCtrl.text.trim();
        cp.background = _backgroundCtrl.text.trim();
      cp.openingLine = _openingLineCtrl.text.trim();
        await pp.saveImmediately(cp);
      }

      // Import AI personas
      for (final p in parsed.personas) {
        await pp.importPersona(p);
      }

      // Fill user persona and world background
      if (parsed.userPersona != null && parsed.userPersona!.isNotEmpty) {
        _userController.text = parsed.userPersona!;
      }
      if (parsed.worldBackground != null && parsed.worldBackground!.isNotEmpty) {
        _worldBgController.text = parsed.worldBackground!;
      }

      // Switch to the first imported persona
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

  void _showExportDialog() {
    showDialog<String>(
      context: context,
      builder: (_) => const ExportPersonaDialog(),
    ).then((json) {
      if (json == null || json.isEmpty || !mounted) return;
      // Defer to next frame so export dialog is fully dismissed
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
