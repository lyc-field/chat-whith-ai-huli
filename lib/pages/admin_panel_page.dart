import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/conversation.dart';
import '../models/ai_persona.dart';
import '../models/emotion_state.dart';
import '../widgets/emotion_grid.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final _promptController = TextEditingController();
  final _roleplayRuleController = TextEditingController();
  final _immersiveRoleplayController = TextEditingController();
  final _newPwController = TextEditingController();
  bool _loading = true;
  bool _adminSafeMode = false;
  double _emotionSensitivity = 1.0;
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prompt = await AuthService.getGlobalPrompt();
    _promptController.text = prompt ?? AuthService.defaultGlobalPrompt;
    final roleplayRule = await AuthService.getRoleplayRule();
    _roleplayRuleController.text =
        roleplayRule ?? AuthService.defaultRoleplayRule;
    final immersiveRoleplayPrompt =
        await AuthService.getImmersiveRoleplayPrompt();
    _immersiveRoleplayController.text = immersiveRoleplayPrompt ??
        AuthService.defaultImmersiveRoleplayPrompt;
    final safeMode = await AuthService.getAdminSafeMode();

    _conversations = await DatabaseService.getConversations();

    final sensitivity = await AuthService.getEmotionSensitivity();

    if (mounted) {
      setState(() {
        _loading = false;
        _adminSafeMode = safeMode;
        _emotionSensitivity = sensitivity;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _roleplayRuleController.dispose();
    _immersiveRoleplayController.dispose();
    _newPwController.dispose();
    super.dispose();
  }

  Future<void> _savePrompt() async {
    await AuthService.setGlobalPrompt(_promptController.text);
    await AuthService.setRoleplayRule(_roleplayRuleController.text);
    await AuthService.setImmersiveRoleplayPrompt(
        _immersiveRoleplayController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('全局规则已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _changePassword() async {
    final newPw = _newPwController.text.trim();
    if (newPw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入新密码'), duration: Duration(seconds: 1)),
      );
      return;
    }
    await AuthService.changePassword(newPw);
    _newPwController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已更改'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _showEmotionAdjustDialog(Conversation conv) async {
    // Load personas for this conversation
    final personas = await DatabaseService.getAIPersonas(conv.id);
    if (personas.isNotEmpty) {
      // New format: let admin pick a persona first
      _showPersonaSelectionDialog(conv, personas);
    } else {
      // Old format: conversation-level emotion adjustment
      _showConversationEmotionDialog(conv);
    }
  }

  String _emotionTemplateStorageKeyFor(String convId, String? personaId) {
    return 'emotion_template_${convId}_${personaId ?? 'default'}';
  }

  Future<Map<String, String>> _loadTemplateLibrary(
      String convId, String? personaId) async {
    final key = _emotionTemplateStorageKeyFor(convId, personaId);
    final raw = await DatabaseService.getSetting(key);
    if (raw == null || raw.trim().isEmpty) return {};

    Map<String, dynamic>? root;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) root = decoded;
    } catch (_) {}
    root ??= {};

    final templates = root['templates'];
    if (templates is! Map) return {};
    final result = <String, String>{};
    for (final e in templates.entries) {
      final k = e.key.toString();
      final v = e.value;
      if (v is String) result[k] = v;
    }
    return result;
  }

  Future<void> _saveTemplateLibrary(
      String convId, String? personaId, Map<String, String> templates) async {
    final key = _emotionTemplateStorageKeyFor(convId, personaId);
    final raw = await DatabaseService.getSetting(key);
    Map<String, dynamic> root = {};
    try {
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is Map<String, dynamic>) root = decoded;
    } catch (_) {}

    root['templates'] = templates;
    await DatabaseService.saveSetting(key, jsonEncode(root));
  }

  Future<void> _showTemplateLibraryEditor(
      {required String convId,
      String? personaId,
      required String title}) async {
    final templates = await _loadTemplateLibrary(convId, personaId);
    if (!mounted) return;

    final keys = templates.keys.toList()..sort();
    if (keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可编辑模板，请先在对话中触发模板生成')),
      );
      return;
    }

    final controllers = <String, TextEditingController>{
      for (final k in keys) k: TextEditingController(text: templates[k] ?? ''),
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('模板库编辑 - $title',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: keys.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final k = keys[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      )),
                  const SizedBox(height: 4),
                  TextField(
                    controller: controllers[k],
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final out = <String, String>{};
              for (final k in keys) {
                out[k] = controllers[k]!.text.trim();
              }
              await _saveTemplateLibrary(convId, personaId, out);
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('模板库已保存'), duration: Duration(seconds: 1)),
              );
            },
            child: const Text('保存全部'),
          ),
        ],
      ),
    );

    for (final c in controllers.values) {
      c.dispose();
    }
  }

  void _showPersonaSelectionDialog(
      Conversation conv, List<AIPersona> personas) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${conv.title} — 选择角色',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: personas.length,
            itemBuilder: (_, i) {
              final p = personas[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${p.affection.round()}',
                      style: const TextStyle(fontSize: 11)),
                ),
                title: Text(p.name.isNotEmpty ? p.name : '未命名角色'),
                subtitle: Text('好感度: ${p.affection.toStringAsFixed(1)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPersonaEmotionDialog(conv, p);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }

  Future<void> _showPersonaEmotionDialog(
      Conversation conv, AIPersona persona) async {
    EmotionState? state =
        await DatabaseService.getPersonaEmotionState(conv.id, persona.id);
    if (state == null) {
      state = EmotionState.createDefault(conv.id,
          initialAffection: persona.affection, personaId: persona.id);
      await DatabaseService.insertPersonaEmotionState(state);
    }
    final s = state; // promoted to non-null by the null check above

    if (!mounted) return;
    double affection = persona.affection;
    double libidoOther = s.currentLibidoOther;
    double aggressionOther = s.currentAggressionOther;
    double libidoSelf = s.currentLibidoSelf;
    double aggressionSelf = s.currentAggressionSelf;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text(persona.name.isNotEmpty ? persona.name : '未命名',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sliderItem('好感度', affection, 0, 100,
                          (v) => setDlgState(() => affection = v)),
                      const Divider(),
                      _sliderItem('对外亲近感', libidoOther, 0, 50,
                          (v) => setDlgState(() => libidoOther = v)),
                      _sliderItem('对外攻击性', aggressionOther, 0, 50,
                          (v) => setDlgState(() => aggressionOther = v)),
                      const Divider(),
                      _sliderItem('自我肯定', libidoSelf, 0, 50,
                          (v) => setDlgState(() => libidoSelf = v)),
                      _sliderItem('自我压力', aggressionSelf, 0, 50,
                          (v) => setDlgState(() => aggressionSelf = v)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setDlgState(() {
                              libidoOther = s.baseLibidoOther;
                              aggressionOther = s.baseAggressionOther;
                              libidoSelf = s.baseLibidoSelf;
                              aggressionSelf = s.baseAggressionSelf;
                            });
                          },
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('重置当前值到基线'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSmallTowardsGrid(
                          affection, libidoOther, aggressionOther),
                      const SizedBox(height: 8),
                      _buildSmallSelfGrid(libidoSelf, aggressionSelf),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    s.affection = affection;
                    s.currentLibidoOther = libidoOther;
                    s.currentAggressionOther = aggressionOther;
                    s.currentLibidoSelf = libidoSelf;
                    s.currentAggressionSelf = aggressionSelf;
                    s.lastUpdate = DateTime.now();
                    persona.affection = affection;
                    await DatabaseService.updatePersonaEmotionState(s);
                    await DatabaseService.updateAIPersona(persona);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('角色情感数值已更新'),
                            duration: Duration(seconds: 1)),
                      );
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showConversationEmotionDialog(Conversation conv) async {
    EmotionState? state = await DatabaseService.getEmotionState(conv.id);
    if (state == null) {
      state = EmotionState.createDefault(conv.id,
          initialAffection: conv.affection.toDouble());
      await DatabaseService.insertEmotionState(state);
    }
    final s = state; // promoted to non-null by the null check above

    if (!mounted) return;
    double affection = s.affection;
    double libidoOther = s.currentLibidoOther;
    double aggressionOther = s.currentAggressionOther;
    double libidoSelf = s.currentLibidoSelf;
    double aggressionSelf = s.currentAggressionSelf;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text(conv.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sliderItem('好感度', affection, 0, 100,
                          (v) => setDlgState(() => affection = v)),
                      const Divider(),
                      _sliderItem('对外亲近感', libidoOther, 0, 50,
                          (v) => setDlgState(() => libidoOther = v)),
                      _sliderItem('对外攻击性', aggressionOther, 0, 50,
                          (v) => setDlgState(() => aggressionOther = v)),
                      const Divider(),
                      _sliderItem('自我肯定', libidoSelf, 0, 50,
                          (v) => setDlgState(() => libidoSelf = v)),
                      _sliderItem('自我压力', aggressionSelf, 0, 50,
                          (v) => setDlgState(() => aggressionSelf = v)),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setDlgState(() {
                              libidoOther = s.baseLibidoOther;
                              aggressionOther = s.baseAggressionOther;
                              libidoSelf = s.baseLibidoSelf;
                              aggressionSelf = s.baseAggressionSelf;
                            });
                          },
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('重置当前值到基线'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSmallTowardsGrid(
                          affection, libidoOther, aggressionOther),
                      const SizedBox(height: 8),
                      _buildSmallSelfGrid(libidoSelf, aggressionSelf),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    s.affection = affection;
                    s.currentLibidoOther = libidoOther;
                    s.currentAggressionOther = aggressionOther;
                    s.currentLibidoSelf = libidoSelf;
                    s.currentAggressionSelf = aggressionSelf;
                    s.lastUpdate = DateTime.now();
                    await DatabaseService.updateEmotionState(s);
                    await DatabaseService.updateConversation(
                        conv.copyWith(affection: affection.round()));
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('情感数值已更新'),
                            duration: Duration(seconds: 1)),
                      );
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSmallTowardsGrid(
      double affection, double libidoOther, double aggressionOther) {
    // Use a minimal EmotionState as a placeholder for the factory.
    final dummyState = EmotionState(id: '', conversationId: '');
    return EmotionGrid.towardsUser(
      state: dummyState,
      affectionOverride: affection,
      libidoOtherOverride: libidoOther,
      aggressionOtherOverride: aggressionOther,
      compact: true,
    );
  }

  Widget _buildSmallSelfGrid(double libidoSelf, double aggressionSelf) {
    final dummyState = EmotionState(id: '', conversationId: '');
    return EmotionGrid.self(
      state: dummyState,
      libidoSelfOverride: libidoSelf,
      aggressionSelfOverride: aggressionSelf,
      compact: true,
    );
  }

  Widget _sliderItem(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(value.toStringAsFixed(1),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) * 2).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('管理面板'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.gpp_maybe, size: 20),
                    const SizedBox(width: 8),
                    Text('全局安全人设',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    const Icon(Icons.lock, size: 14, color: Colors.grey),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '此设定对所有对话生效，优先于各对话自己的角色规则。普通用户无法修改。',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final globalPromptField = TextField(
                        controller: _promptController,
                        maxLines: 6,
                        minLines: 3,
                        decoration: const InputDecoration(
                          labelText: '全局系统提示词',
                          border: OutlineInputBorder(),
                        ),
                      );
                      final roleplayRuleField = TextField(
                        controller: _roleplayRuleController,
                        maxLines: 6,
                        minLines: 3,
                        decoration: const InputDecoration(
                          labelText: '第二轮角色规则',
                          border: OutlineInputBorder(),
                        ),
                      );
                      final immersiveRoleplayField = TextField(
                        controller: _immersiveRoleplayController,
                        maxLines: 8,
                        minLines: 4,
                        decoration: const InputDecoration(
                          labelText: '沉浸演绎规则',
                          helperText:
                              '用于虚构角色扮演中的自然互动和减少误拒绝；不能覆盖更高优先级的安全规则。',
                          border: OutlineInputBorder(),
                        ),
                      );
                      if (constraints.maxWidth >= 600) {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: globalPromptField),
                                const SizedBox(width: 12),
                                Expanded(child: roleplayRuleField),
                              ],
                            ),
                            const SizedBox(height: 12),
                            immersiveRoleplayField,
                          ],
                        );
                      }
                      return Column(
                        children: [
                          globalPromptField,
                          const SizedBox(height: 12),
                          roleplayRuleField,
                          const SizedBox(height: 12),
                          immersiveRoleplayField,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _savePrompt,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('保存全局规则'),
                  ),
                ],
              ),
            ),
          ),
          // ─── Affection Configuration ────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(children: [
              const Icon(Icons.favorite, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text('好感度系统', style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),

          // Admin safe mode
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.shield),
              title: const Text('管理员安心模式'),
              subtitle: const Text('开启后所有对话好感度不再变化'),
              value: _adminSafeMode,
              onChanged: (v) async {
                await AuthService.setAdminSafeMode(v);
                setState(() => _adminSafeMode = v);
              },
            ),
          ),

          // Per-conversation emotion editing
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.tune, size: 20),
                    const SizedBox(width: 8),
                    Text('各对话情感调节',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 4),
                  Text('点按对话进入情感数值调节面板',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline)),
                  const SizedBox(height: 12),
                  if (_conversations.isEmpty)
                    Text('暂无对话', style: Theme.of(context).textTheme.bodySmall)
                  else
                    ..._conversations.map((c) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _showEmotionAdjustDialog(c),
                            child: Row(children: [
                              Expanded(
                                child: Text(c.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.outline),
                            ]),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Temperature explanation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.thermostat, size: 20),
                    const SizedBox(width: 8),
                    Text('AI 回复温度',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '好感度越高，AI 回复的 temperature 越高，回复越富有创造性和随机性。'
                    '好感度越低，回复越保守和确定。',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  // Visual bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 20,
                      child: Row(children: [
                        Expanded(
                            flex: 10,
                            child: Container(color: Colors.blue.shade200)),
                        Expanded(
                            flex: 10,
                            child: Container(color: Colors.blue.shade300)),
                        Expanded(
                            flex: 10,
                            child: Container(color: Colors.blue.shade400)),
                        Expanded(
                            flex: 10,
                            child: Container(color: Colors.orange.shade300)),
                        Expanded(
                            flex: 10,
                            child: Container(color: Colors.orange.shade400)),
                        Expanded(
                            flex: 10,
                            child: Container(color: Colors.red.shade300)),
                        Expanded(
                            flex: 10,
                            child: Container(color: Colors.red.shade400)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('-15',
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Text('30',
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Text('50',
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Text('80',
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Text('100',
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.outline)),
                  ]),
                  const SizedBox(height: 4),
                  Text('好感度 →',
                      style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
          ),

          // ─── Emotion System Configuration ────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(children: [
              const Icon(Icons.psychology, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text('情感系统', style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('情绪变化灵敏度',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                      '数值越高，每次对话情绪波动越大（当前：${_emotionSensitivity.toStringAsFixed(2)}）',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline)),
                  Slider(
                    value: _emotionSensitivity,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    onChanged: (v) {
                      setState(() => _emotionSensitivity = v);
                    },
                    onChangeEnd: (v) async {
                      await AuthService.setEmotionSensitivity(v);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.key, size: 20),
                    const SizedBox(width: 8),
                    Text('修改管理员密码',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPwController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '新密码',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('更改密码'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
