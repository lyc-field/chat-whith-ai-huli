import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import '../services/knowledge_base.dart';

class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  bool _importing = false;
  int _progress = 0;
  int _total = 0;
  String _currentFile = '';
  int _chunkCount = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    _chunkCount = await KnowledgeBase.chunkCount();
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _startImportFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择资料库文件夹',
    );
    if (result == null) return;
    await _runImport(result);
  }

  Future<void> _startImportFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['txt', 'zip', '7z'],
    );
    if (result == null || result.files.isEmpty) return;
    // Copy files to a temp dir and import from there
    final tmpDir = await Directory.systemTemp.createTemp('kb_import_');
    for (final f in result.files) {
      if (f.path != null) {
        final src = File(f.path!);
        await src.copy(join(tmpDir.path, f.name));
      }
    }
    await _runImport(tmpDir.path);
    await tmpDir.delete(recursive: true);
  }

  Future<void> _runImport(String path) async {
    setState(() {
      _importing = true;
      _progress = 0;
      _total = 0;
    });

    await KnowledgeBase.importDirectory(
      path,
      onProgress: (current, total, fileName) {
        if (mounted) {
          setState(() {
            _progress = current;
            _total = total;
            _currentFile = fileName;
          });
        }
      },
    );

    _chunkCount = await KnowledgeBase.chunkCount();
    if (mounted) {
      setState(() {
        _importing = false;
        _currentFile = '';
      });
    }
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: this.context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空资料库'),
        content: const Text('确定要删除所有已导入的资料吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await KnowledgeBase.clearAll();
      await _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('资料库管理'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_loaded)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(Icons.storage, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('已索引 $_chunkCount 个文本片段',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('片段越多，AI 参考素材越丰富',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Import buttons
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _importing ? null : _startImportFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('导入文件夹'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importing ? null : _startImportFiles,
                  icon: const Icon(Icons.insert_drive_file),
                  label: const Text('导入文件'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('支持 .txt / .zip / .7z，文件夹或单独文件均可。已导入的不会重复。',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // Progress
            if (_importing) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    LinearProgressIndicator(value: _total > 0 ? _progress / _total : null),
                    const SizedBox(height: 12),
                    Text('正在导入 $_progress / $_total',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text(_currentFile,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Clear button
            if (_chunkCount > 0) ...[
              OutlinedButton.icon(
                onPressed: _importing ? null : _clearAll,
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('清空资料库'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
