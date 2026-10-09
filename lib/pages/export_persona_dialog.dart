import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/persona_provider.dart';
import '../providers/chat_provider.dart';
import '../services/persona_io.dart';

class ExportPersonaDialog extends StatefulWidget {
  const ExportPersonaDialog({super.key});

  @override
  State<ExportPersonaDialog> createState() => _ExportPersonaDialogState();
}

class _ExportPersonaDialogState extends State<ExportPersonaDialog> {
  late List<bool> _personaChecked;
  bool _exportUser = false;
  bool _exportOpening = false;
  bool _exportWorld = false;

  @override
  void initState() {
    super.initState();
    final pp = context.read<PersonaProvider>();
    _personaChecked = List.filled(pp.personas.length, true);
    _exportUser = true;
    _exportOpening = true;
    _exportWorld = true;
  }

  void _selectAll() {
    setState(() {
      for (int i = 0; i < _personaChecked.length; i++) {
        _personaChecked[i] = true;
      }
      _exportUser = true;
      _exportOpening = true;
      _exportWorld = true;
    });
  }

  void _doExport() {
    final pp = context.read<PersonaProvider>();
    final chat = context.read<ChatProvider>();

    final selectedPersonas = pp.personas.toList();

    if (selectedPersonas.isEmpty && !_exportUser && !_exportWorld) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请至少选择一项导出内容'), duration: Duration(seconds: 1)),
      );
      return;
    }

    final json = PersonaIO.buildExportJson(
      selectedPersonas: selectedPersonas,
      userPersona: chat.userPersona,
      openingLine: chat.openingLine,
      worldBackground: chat.worldBackground,
    );

    // Return JSON to caller — caller handles file naming + sharing
    Navigator.pop(context, json);
  }

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<PersonaProvider>();
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('导出角色包'),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI 角色人设', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              const Text(
                '将自动完整导出当前对话中的全部角色、人设模式、示例对话和初始好感度。',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 6),
              if (pp.personas.isEmpty)
                Text('暂无角色',
                    style: TextStyle(
                        color: theme.colorScheme.outline, fontSize: 13))
              else
                ...List.generate(pp.personas.length, (i) {
                  final p = pp.personas[i];
                  return CheckboxListTile(
                    value: _personaChecked[i],
                    onChanged: null,
                    title: Text(p.name.isNotEmpty ? p.name : '未命名角色',
                        style: const TextStyle(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              const Divider(height: 20),
              CheckboxListTile(
                value: _exportUser,
                onChanged: null,
                title: Text('用户人设',
                    style: TextStyle(
                        fontSize: 14, color: theme.colorScheme.onSurface)),
                subtitle: Text(
                    context.read<ChatProvider>().userPersona ?? '(未设置)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.outline)),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 20),
              CheckboxListTile(
                value: _exportOpening,
                onChanged: null,
                title: Text('开场白',
                    style: TextStyle(
                        fontSize: 14, color: theme.colorScheme.onSurface)),
                subtitle: Text(
                    context.read<ChatProvider>().openingLine ?? '(未设置)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.outline)),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(height: 20),
              CheckboxListTile(
                value: _exportWorld,
                onChanged: null,
                title: Text('世界背景',
                    style: TextStyle(
                        fontSize: 14, color: theme.colorScheme.onSurface)),
                subtitle: Text(
                    context.read<ChatProvider>().worldBackground ?? '(未设置)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: theme.colorScheme.outline)),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.outline),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _selectAll,
          style:
              TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
          child: const Text('全选'),
        ),
        FilledButton(
          onPressed: _doExport,
          style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary),
          child: const Text('确定导出'),
        ),
      ],
    );
  }
}
