import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../models/ai_persona.dart';

class PersonaIO {
  static const _appMarker = 'xiaohu-persona-pack';
  static const _version = 1;
  static const _secretKey = 'xh-ai-chat-2024-secret';

  // ─── XOR + Base64 encryption ───

  static String _encrypt(String plain) {
    final bytes = utf8.encode(plain);
    final keyBytes = utf8.encode(_secretKey);
    final result = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64Encode(result);
  }

  static String _decrypt(String encoded) {
    final bytes = base64Decode(encoded);
    final keyBytes = utf8.encode(_secretKey);
    final result = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return utf8.decode(result);
  }

  static bool _isEncrypted(String content) {
    final trimmed = content.trim();
    // encrypted files start with a base64-looking character, plain JSON starts with '{'
    return !trimmed.startsWith('{');
  }

  // ─── Export / Import ───

  /// Build export JSON from selected personas, user persona, world background.
  /// Returns encrypted content (XOR + Base64).
  static String buildExportJson({
    required List<AIPersona> selectedPersonas,
    required String? userPersona,
    required String? openingLine,
    required String? worldBackground,
  }) {
    final map = <String, dynamic>{
      'app': _appMarker,
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'personas': selectedPersonas.map((p) => {
        'name': p.name,
        'identity': p.identity,
        'personality': p.personality,
        'appearance': p.appearance,
        'notes': p.notes,
      }).toList(),
      'user_persona': (userPersona != null && userPersona.trim().isNotEmpty)
          ? userPersona.trim()
          : null,
      'opening_line': (openingLine != null && openingLine.trim().isNotEmpty)
          ? openingLine.trim()
          : null,
      'world_background': (worldBackground != null && worldBackground.trim().isNotEmpty)
          ? worldBackground.trim()
          : null,
    };
    const encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(map);
    return _encrypt(json);
  }

  /// Share encrypted data via system share sheet with a custom filename.
  static Future<void> shareJson({
    required String json,
    required String fileName,
    String subject = '分享角色人设包',
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(json));
    final xFile = XFile.fromData(
      bytes,
      name: fileName.endsWith('.xhp') ? fileName : '$fileName.xhp',
      mimeType: 'application/octet-stream',
    );
    await Share.shareXFiles(
      [xFile],
      subject: subject,
    );
  }

  /// Parse and validate an imported file content.
  /// Supports both encrypted (.xhp) and legacy plain JSON (.json) files.
  static ({List<AIPersona> personas, String? userPersona, String? worldBackground, String? openingLine, String? error}) parseImportJson(String raw) {
    try {
      // Try decryption first (for .xhp files); fall back to plain JSON (for legacy .json files)
      final jsonStr = _isEncrypted(raw) ? _decrypt(raw.trim()) : raw;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (map['app'] != _appMarker) {
        return (personas: [], userPersona: null, worldBackground: null, openingLine: null, error: '文件格式不匹配，仅支持导入本应用导出的角色包');
      }

      final personas = <AIPersona>[];
      final personaList = map['personas'] as List<dynamic>?;
      if (personaList != null) {
        for (final p in personaList) {
          final pm = p as Map<String, dynamic>;
          personas.add(AIPersona(
            name: (pm['name'] as String?) ?? '',
            identity: (pm['identity'] as String?) ?? '',
            personality: (pm['personality'] as String?) ?? '',
            appearance: (pm['appearance'] as String?) ?? '',
            notes: (pm['notes'] as String?) ?? '',
          ));
        }
      }

      return (
        personas: personas,
        userPersona: map['user_persona'] as String?,
        worldBackground: map['world_background'] as String?,
        openingLine: map['opening_line'] as String?,
        error: null,
      );
    } catch (_) {
      return (personas: [], userPersona: null, worldBackground: null, openingLine: null, error: '文件格式错误，无法解析该文件');
    }
  }

  /// Read a file from a file path (binary safe).
  static Future<String> readJsonFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file.readAsString(encoding: utf8);
    }
    throw Exception('文件不存在');
  }
}
