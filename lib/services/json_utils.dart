import 'dart:convert';

/// Shared JSON extraction utility used by both ChatProvider and EmotionService.
/// Handles LLM responses that may wrap JSON in extra text.
class JsonUtils {
  static Map<String, dynamic>? extractJson(String text) {
  // 1. Try direct parse first.
  try {
    return jsonDecode(text.trim()) as Map<String, dynamic>;
  } catch (_) {}

  // 2. Try to find a balanced JSON block (handles nested objects correctly).
  final start = text.indexOf('{');
  if (start == -1) return null;

  var depth = 0;
  var end = -1;
  for (var i = start; i < text.length; i++) {
    if (text[i] == '{') depth++;
    if (text[i] == '}') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }

  if (end == -1) return null;

  try {
    return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}
}
