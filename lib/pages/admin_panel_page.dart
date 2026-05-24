import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/conversation.dart';
import '../models/ai_persona.dart';
import '../models/emotion_state.dart';
import '../widgets/emotion_grid.dart';
import 'knowledge_base_page.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final _promptController = TextEditingController();
  final _newPwController = TextEditingController();
  bool _loading = true;
  bool _adminSafeMode = false;
  double _emotionSensitivity = 1.0;
  double _emotionDecayHours = 2.0;
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prompt = await AuthService.getGlobalPrompt();
    _promptController.text = prompt ?? AuthService.defaultGlobalPrompt;
    final safeMode = await AuthService.getAdminSafeMode();

    _conversations = await DatabaseService.getConversations();

    final sensitivity = await AuthService.getEmotionSensitivity();
    final decayHours = await AuthService.getEmotionDecayHours();

    if (mounted) {
      setState(() {
        _loading = false;
        _adminSafeMode = safeMode;
        _emotionSensitivity = sensitivity;
        _emotionDecayHours = decayHours;
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _newPwController.dispose();
    super.dispose();
  }

  Future<void> _savePrompt() async {
    await AuthService.setGlobalPrompt(_promptController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全局人设已保存'), duration: Duration(seconds: 1)),
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

  void _showPersonaSelectionDialog(Conversation conv, List<AIPersona> personas) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${conv.title} — 选择角色', maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: personas.length,
            itemBuilder: (_, i) {
              final p = personas[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${p.affection.round()}', style: const TextStyle(fontSize: 11)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }

  Future<void> _showPersonaEmotionDialog(Conversation conv, AIPersona persona) async {
    EmotionState? state = await DatabaseService.getPersonaEmotionState(conv.id, persona.id);
    if (state == null) {
      state = EmotionState.createDefault(conv.id, initialAffection: persona.affection, personaId: persona.id);
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
              title: Text(persona.name.isNotEmpty ? persona.name : '未命名', maxLines: 1, overflow: TextOverflow.ellipsis),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sliderItem('好感度', affection, 0, 100, (v) => setDlgState(() => affection = v)),
                      const Divider(),
                      _sliderItem('他力比多', libidoOther, 0, 50, (v) => setDlgState(() => libidoOther = v)),
                      _sliderItem('他攻击性', aggressionOther, 0, 50, (v) => setDlgState(() => aggressionOther = v)),
                      const Divider(),
                      _sliderItem('自力比多', libidoSelf, 0, 50, (v) => setDlgState(() => libidoSelf = v)),
                      _sliderItem('自攻击性', aggressionSelf, 0, 50, (v) => setDlgState(() => aggressionSelf = v)),
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
                      _buildSmallTowardsGrid(affection, libidoOther, aggressionOther),
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
                        const SnackBar(content: Text('角色情感数值已更新'),
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
      state = EmotionState.createDefault(conv.id, initialAffection: conv.affection.toDouble());
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
              title: Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sliderItem('好感度', affection, 0, 100, (v) => setDlgState(() => affection = v)),
                      const Divider(),
                      _sliderItem('他力比多', libidoOther, 0, 50, (v) => setDlgState(() => libidoOther = v)),
                      _sliderItem('他攻击性', aggressionOther, 0, 50, (v) => setDlgState(() => aggressionOther = v)),
                      const Divider(),
                      _sliderItem('自力比多', libidoSelf, 0, 50, (v) => setDlgState(() => libidoSelf = v)),
                      _sliderItem('自攻击性', aggressionSelf, 0, 50, (v) => setDlgState(() => aggressionSelf = v)),
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
                      _buildSmallTowardsGrid(affection, libidoOther, aggressionOther),
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
                        const SnackBar(content: Text('情感数值已更新'),
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

  Widget _buildSmallTowardsGrid(double affection, double libidoOther, double aggressionOther) {
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

  Widget _sliderItem(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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
                    Text('全局安全人设', style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    const Icon(Icons.lock, size: 14, color: Colors.grey),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '此设定对所有对话生效，优先于各对话自己的角色规则。普通用户无法修改。',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    maxLines: 6,
                    minLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '输入全局系统提示词...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _savePrompt,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('保存全局人设'),
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
                    Text('各对话情感调节', style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 4),
                  Text('点按对话进入情感数值调节面板',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
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
                                    style: Theme.of(context).textTheme.bodySmall),
                              ),
                              Icon(Icons.chevron_right, size: 16,
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
                    Text('AI 回复温度', style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '好感度越高，AI 回复的 temperature 越高，回复越富有创造性和随机性。'
                    '好感度越低，回复越保守和确定。',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  // Visual bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 20,
                      child: Row(children: [
                        Expanded(flex: 10, child: Container(color: Colors.blue.shade200)),
                        Expanded(flex: 10, child: Container(color: Colors.blue.shade300)),
                        Expanded(flex: 10, child: Container(color: Colors.blue.shade400)),
                        Expanded(flex: 10, child: Container(color: Colors.orange.shade300)),
                        Expanded(flex: 10, child: Container(color: Colors.orange.shade400)),
                        Expanded(flex: 10, child: Container(color: Colors.red.shade300)),
                        Expanded(flex: 10, child: Container(color: Colors.red.shade400)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('-15', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Text('30', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Text('50', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Text('80', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                    const Spacer(),
                    Text('100', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                  ]),
                  const SizedBox(height: 4),
                  Text('好感度 →', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('数值越高，每次对话情绪波动越大（当前：${_emotionSensitivity.toStringAsFixed(2)}）',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
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
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('情绪衰减时长',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('情绪偏离基线后，经过此时长完全恢复（当前：${_emotionDecayHours.toStringAsFixed(1)} 小时）',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                  Slider(
                    value: _emotionDecayHours,
                    min: 0.5,
                    max: 12.0,
                    divisions: 23,
                    onChanged: (v) {
                      setState(() => _emotionDecayHours = v);
                    },
                    onChangeEnd: (v) async {
                      await AuthService.setEmotionDecayHours(v);
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
                    Text('修改管理员密码', style: Theme.of(context).textTheme.titleMedium),
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
          // ── 资料库 ──
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.library_books, size: 24),
              title: const Text('资料库管理'),
              subtitle: const Text('导入小说文本，让AI参考写作风格'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const KnowledgeBasePage()));
              },
            ),
          ),
        ],
      ),
    );
  }
}
