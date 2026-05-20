import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../models/ai_persona.dart';

class PersonaIO {
  static const _appMarker = 'xiaohu-persona-pack';
  static const _version = 1;

  /// Build export JSON from selected personas, user persona, world background.
  static String buildExportJson({
    required List<AIPersona> selectedPersonas,
    required String? userPersona,
    required String? worldBackground,
  }) {
    final map = <String, dynamic>{
      'app': _appMarker,
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'personas': selectedPersonas.map((p) => {
        'name': p.name,
        'personality': p.personality,
        'habits': p.habits,
        'appearance': p.appearance,
        'background': p.background,
        'opening_line': p.openingLine,
      }).toList(),
      'user_persona': (userPersona != null && userPersona.trim().isNotEmpty)
          ? userPersona.trim()
          : null,
      'world_background': (worldBackground != null && worldBackground.trim().isNotEmpty)
          ? worldBackground.trim()
          : null,
    };
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(map);
  }

  /// Share JSON data via system share sheet with a custom filename.
  static Future<void> shareJson({
    required String json,
    required String fileName,
    String subject = '分享角色人设包',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(json));
    final xFile = XFile.fromData(
      bytes,
      name: fileName.endsWith('.json') ? fileName : '$fileName.json',
      mimeType: 'application/json',
    );
    await Share.shareXFiles(
      [xFile],
      subject: subject,
    );
  }

  /// Parse and validate an imported JSON string.
  /// Returns null error on success.
  static ({List<AIPersona> personas, String? userPersona, String? worldBackground, String? error}) parseImportJson(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      if (map['app'] != _appMarker) {
        return (personas: [], userPersona: null, worldBackground: null, error: '文件格式不匹配，仅支持导入本应用导出的角色包');
      }

      final personas = <AIPersona>[];
      final personaList = map['personas'] as List<dynamic>?;
      if (personaList != null) {
        for (final p in personaList) {
          final pm = p as Map<String, dynamic>;
          personas.add(AIPersona(
            name: (pm['name'] as String?) ?? '',
            personality: (pm['personality'] as String?) ?? '',
            habits: (pm['habits'] as String?) ?? '',
            appearance: (pm['appearance'] as String?) ?? '',
            background: (pm['background'] as String?) ?? '',
            openingLine: (pm['opening_line'] as String?) ?? '',
          ));
        }
      }

      return (
        personas: personas,
        userPersona: map['user_persona'] as String?,
        worldBackground: map['world_background'] as String?,
        error: null,
      );
    } catch (_) {
      return (personas: [], userPersona: null, worldBackground: null, error: 'JSON 格式错误，无法解析该文件');
    }
  }

  /// Read JSON from a file path.
  static Future<String> readJsonFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file.readAsString(encoding: utf8);
    }
    throw Exception('文件不存在');
  }
}
