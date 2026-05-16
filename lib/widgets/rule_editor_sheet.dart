import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/auth_service.dart';

/// Extracted rule editor modal bottom sheet.
/// Shows persona editor with JSON import, quick reply tone selector, and affection slider.
void showRuleEditorSheet(
  BuildContext context, {
  required TextEditingController ruleController,
  required int affectionSlider,
  required void Function(int) onAffectionSliderChanged,
  required String quickReplyTone,
  required void Function(String) onQuickReplyToneChanged,
}) {
  final provider = context.read<ChatProvider>();
  final initialAffection = affectionSlider;
  String currentTone = quickReplyTone;
  String? globalRules;
  bool showRules = false;

  // Load global rules.
  AuthService.getGlobalPrompt().then((p) => globalRules = p);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final hasGlobal = globalRules != null && globalRules!.trim().isNotEmpty;
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, size: 20),
                  const SizedBox(width: 8),
                  Text('角色规则', style: Theme.of(ctx).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ruleController.clear();
                      provider.setSystemPrompt('');
                      Navigator.pop(ctx);
                    },
                    child: const Text('清除'),
                  ),
                ]),
                if (hasGlobal) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setSheetState(() => showRules = !showRules),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme.tertiaryContainer
                            .withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        Icon(Icons.gpp_maybe, size: 14,
                            color: Theme.of(context).colorScheme.tertiary),
                        const SizedBox(width: 6),
                        Text('管理员安全规则',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.tertiary)),
                        const Spacer(),
                        Icon(showRules ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: Theme.of(context).colorScheme.tertiary),
                      ]),
                    ),
                  ),
                  if (showRules) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme.surfaceVariant
                            .withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        globalRules!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme.onSurfaceVariant
                              .withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                // Quick reply tone selector
                Row(children: [
                  const Text('快捷回复语气', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  ...AuthService.quickReplyTones.map((t) {
                    final selected = currentTone == t;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(t, style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white : null)),
                        selected: selected,
                        onSelected: (_) => setSheetState(() {
                          currentTone = t;
                          onQuickReplyToneChanged(t);
                        }),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }),
                ]),
                const SizedBox(height: 8),
                // Import JSON persona
                OutlinedButton.icon(
                  onPressed: () => _importPersona(context, ctx, setSheetState,
                      ruleController, initialAffection, onAffectionSliderChanged),
                  icon: const Icon(Icons.file_open, size: 16),
                  label: const Text('导入 JSON 人设'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ruleController,
                  autofocus: true,
                  maxLines: 8,
                  minLines: 3,
                  decoration: const InputDecoration(
                    hintText: '设定 AI 的角色和行为规则...\n\n例如：你是一只可爱的小狐狸，名字叫眠眠，活泼开朗，喜欢用"~"和颜文字',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Initial affection — only settable when persona is first created
                if (provider.systemPrompt == null || provider.systemPrompt!.isEmpty) ...[
                  if (provider.affectionEnabled) ...[
                    Row(children: [
                      const Icon(Icons.favorite, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('初始好感度', style: Theme.of(ctx).textTheme.bodySmall),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Slider(
                          value: initialAffection.toDouble(),
                          min: 10,
                          max: 50,
                          divisions: 40,
                          label: '$initialAffection',
                          onChanged: (v) {
                            onAffectionSliderChanged(v.round());
                            setSheetState(() {});
                          },
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text('$initialAffection',
                            style: Theme.of(ctx).textTheme.bodySmall),
                      ),
                    ]),
                    const SizedBox(height: 8),
                  ],
                ] else ...[
                  if (provider.affectionEnabled) ...[
                    Row(children: [
                      const Icon(Icons.favorite, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('当前好感度：${provider.affection}（由系统自动管理）',
                          style: Theme.of(ctx).textTheme.bodySmall),
                    ]),
                    const SizedBox(height: 8),
                  ],
                ],
                FilledButton.icon(
                  onPressed: () {
                    if (provider.systemPrompt == null || provider.systemPrompt!.isEmpty) {
                      provider.setInitialAffection(initialAffection);
                    }
                    AuthService.setQuickReplyTone(currentTone);
                    provider.setSystemPrompt(ruleController.text);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('规则已保存'), duration: Duration(seconds: 1)),
                    );
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('保存规则'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> _importPersona(
  BuildContext context,
  BuildContext sheetCtx,
  void Function(void Function()) setSheetState,
  TextEditingController ruleController,
  int initialAffection,
  void Function(int) onAffectionSliderChanged,
) async {
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
    // Try simple format first, then complex nested format
    var persona = json['persona'] as String? ?? '';
    var name = json['name'] as String?;
    var aff = json['initial_affection'] as int?;
    if (persona.isEmpty) {
      // Complex format: data.prompts.<variant>.data
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
    if (!context.mounted) return;
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
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
      setSheetState(() {
        if (persona.isNotEmpty) ruleController.text = persona;
        if (aff != null) onAffectionSliderChanged(aff.clamp(10, 50));
      });
    }
  } catch (_) {
    if (context.mounted) {
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
