/// Offline tool: build a pre-indexed SQLite knowledge base from txt files.
///
/// Usage:
///   dart run tool/build_kb.dart --input "E:/萝莉小说合集" --output build/kb_prebuilt.db
///
/// The output DB can be gzip-compressed and placed in assets/ for app bundling.

import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<void> main(List<String> args) async {
  final inputDir = _arg(args, '--input') ?? 'E:/萝莉小说合集';
  final outputPath = _arg(args, '--output') ?? 'build/kb_prebuilt.db';

  print('Building knowledge base...');
  print('  Input:  $inputDir');
  print('  Output: $outputPath');

  // Delete existing
  if (await File(outputPath).exists()) {
    await File(outputPath).delete();
    print('  Deleted existing DB');
  }

  final db = await openDatabase(
    outputPath,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE VIRTUAL TABLE kb_chunks USING fts5(
          title,
          content,
          tokenize='unicode61'
        )
      ''');
      await db.execute('''
        CREATE TABLE kb_import_log (
          file_path TEXT PRIMARY KEY,
          file_name TEXT NOT NULL,
          imported_at TEXT NOT NULL
        )
      ''');
    },
  );

  final dir = Directory(inputDir);
  if (!await dir.exists()) {
    print('ERROR: input directory does not exist');
    exit(1);
  }

  int fileCount = 0;
  int chunkCount = 0;

  await for (final entity in dir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.txt')) {
      fileCount++;
      try {
        final content = await entity.readAsString(encoding: utf8);
        final chunks = _chunkText(content, 400);
        for (final chunk in chunks) {
          if (chunk.trim().isNotEmpty) {
            await db.insert('kb_chunks', {
              'title': entity.path,
              'content': chunk,
            });
            chunkCount++;
          }
        }
        await db.insert('kb_import_log', {
          'file_path': entity.path,
          'file_name': entity.path,
          'imported_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        print('  SKIP: ${entity.path}');
      }

      if (fileCount % 50 == 0) {
        print('  $fileCount files, $chunkCount chunks...');
      }
    }
  }

  await db.close();

  print('Done: $fileCount files, $chunkCount chunks indexed.');
  print('Output: $outputPath');
  print('');
  print('To bundle with the app:');
  print('  1. Compress: gzip -k $outputPath');
  print('  2. Move to assets: move $outputPath.gz assets/');
  print('  3. The app will auto-load it on first launch');
}

String? _arg(List<String> args, String name) {
  final idx = args.indexOf(name);
  return (idx >= 0 && idx + 1 < args.length) ? args[idx + 1] : null;
}

List<String> _chunkText(String text, int size) {
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
