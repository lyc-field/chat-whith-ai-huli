import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'database_service.dart';

class KnowledgeBase {
  static bool _importing = false;
  static bool _prebuiltChecked = false;
  static bool get isImporting => _importing;

  /// Check for and load a pre-built database on first launch.
  static Future<void> initPrebuilt() async {
    if (_prebuiltChecked) return;
    _prebuiltChecked = true;

    final count = await DatabaseService.kbChunkCount();
    if (count > 0) return;

    try {
      final data = await rootBundle.load('assets/kb_prebuilt.db');
      final dir = await getApplicationDocumentsDirectory();
      final destPath = join(dir.path, '_kb_prebuilt_temp.db');
      final destFile = File(destPath);
      await destFile.writeAsBytes(data.buffer.asUint8List());

      final db = await DatabaseService.database;
      await db.execute("ATTACH DATABASE '$destPath' AS prebuilt");
      try {
        await db.execute(
          'INSERT INTO main.kb_chunks SELECT * FROM prebuilt.kb_chunks');
        await db.execute(
          'INSERT INTO main.kb_import_log SELECT * FROM prebuilt.kb_import_log');
      } finally {
        await db.execute('DETACH prebuilt');
      }
      try { await destFile.delete(); } catch (_) {}
      final total = await DatabaseService.kbChunkCount();
      debugPrint('KnowledgeBase: pre-built DB loaded, $total chunks');
    } catch (e) {
      debugPrint('KnowledgeBase: no pre-built DB found, will need manual import ($e)');
    }
  }

  /// Import all supported files from a directory.
  /// Supports: .txt, .zip, .7z (desktop only for 7z)
  static Future<void> importDirectory(
    String dirPath, {
    void Function(int current, int total, String fileName)? onProgress,
  }) async {
    if (_importing) return;
    _importing = true;

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      final imported = await DatabaseService.getImportedFiles();

      // Collect .txt files and archives
      final txtFiles = <File>[];
      final archives = <File>[];

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final p = entity.path;
          if (imported.contains(p)) continue;
          if (p.endsWith('.txt')) {
            txtFiles.add(entity);
          } else if (p.endsWith('.zip')) {
            archives.add(entity);
          } else if (p.endsWith('.7z')) {
            archives.add(entity);
          }
        }
      }

      if (txtFiles.isEmpty && archives.isEmpty) {
        _importing = false;
        return;
      }

      int processed = 0;
      final total = txtFiles.length + archives.length;

      // Import direct .txt files
      for (final file in txtFiles) {
        processed++;
        final name = file.path.split(Platform.pathSeparator).last;
        onProgress?.call(processed, total, name);
        await _importTextFile(file.path, file.path);
        await DatabaseService.markFileImported(file.path, file.path);
      }

      // Import archives
      for (final archive in archives) {
        processed++;
        final name = archive.path.split(Platform.pathSeparator).last;
        onProgress?.call(processed, total, name);
        await _importArchive(archive.path);
        await DatabaseService.markFileImported(archive.path, archive.path);
      }
    } finally {
      _importing = false;
    }
  }

  /// Import a single .txt file into FTS5.
  static Future<void> _importTextFile(String filePath, String displayTitle) async {
    try {
      final content = await File(filePath).readAsString(encoding: utf8);
      final chunks = _chunkText(content, 400);
      for (final chunk in chunks) {
        if (chunk.trim().isNotEmpty) {
          await DatabaseService.insertKbChunk(displayTitle, chunk);
        }
      }
    } catch (_) {}
  }

  /// Import an archive (.zip or .7z), extracting and indexing txt files inside.
  static Future<void> _importArchive(String archivePath) async {
    if (archivePath.endsWith('.zip')) {
      await _importZip(archivePath);
    } else if (archivePath.endsWith('.7z')) {
      await _import7z(archivePath);
    }
  }

  /// Extract and import .zip archives using the archive package.
  static Future<void> _importZip(String zipPath) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.txt')) {
          try {
            final content = utf8.decode(file.content as List<int>);
            final chunks = _chunkText(content, 400);
            for (final chunk in chunks) {
              if (chunk.trim().isNotEmpty) {
                await DatabaseService.insertKbChunk(
                  '$zipPath :: ${file.name}', chunk);
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Extract and import .7z archives via system 7z CLI (desktop only).
  static Future<void> _import7z(String path7z) async {
    try {
      // Try to find 7z executable
      final sevenZip = await _find7z();
      if (sevenZip == null) return;

      final tmpDir = await Directory.systemTemp.createTemp('kb_7z_');
      final result = await Process.run(sevenZip, [
        'x', path7z, '-o${tmpDir.path}', '-y',
      ]);
      if (result.exitCode != 0) return;

      await for (final entity in tmpDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.txt')) {
          await _importTextFile(entity.path, '$path7z :: ${entity.path.split(Platform.pathSeparator).last}');
        }
      }
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  }

  static Future<String?> _find7z() async {
    // Try common 7z paths
    final candidates = [
      r'C:\Program Files\7-Zip\7z.exe',
      r'C:\Program Files (x86)\7-Zip\7z.exe',
      '7z',
      '7z.exe',
      '/usr/bin/7z',
      '/usr/local/bin/7z',
    ];
    for (final c in candidates) {
      try {
        final result = await Process.run(c, ['--help']);
        if (result.exitCode == 0 || result.stderr.toString().contains('7-Zip')) {
          return c;
        }
      } catch (_) {}
    }
    return null;
  }

  static List<String> _chunkText(String text, int size) {
    final chunks = <String>[];
    final sentences = text.split(RegExp(r'(?<=[。！？\n])'));
    var buffer = StringBuffer();
    for (final s in sentences) {
      if (buffer.length + s.length > size && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer = StringBuffer();
      }
      buffer.write(s);
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks;
  }

  static Future<List<({String title, String content})>> search(String query, {int limit = 5}) async {
    final rows = await DatabaseService.searchKb(query, limit: limit);
    return [
      for (final r in rows)
        (title: (r['title'] as String?) ?? '', content: (r['content'] as String?) ?? ''),
    ];
  }

  static Future<int> chunkCount() => DatabaseService.kbChunkCount();
  static Future<void> clearAll() => DatabaseService.clearKb();
}
