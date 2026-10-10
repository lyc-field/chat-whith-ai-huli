import 'dart:convert';

import 'json_utils.dart';

/// Parsed assistant envelope. Unknown JSON fields are retained for future
/// extensions without changing the chat UI contract.
class StructuredReply {
  final String reply;
  final double? affectionDelta;
  final String affectionReason;
  final List<String> quickReplies;
  final Map<String, dynamic> extra;
  final bool isStructured;

  const StructuredReply({
    required this.reply,
    this.affectionDelta,
    this.affectionReason = '',
    this.quickReplies = const [],
    this.extra = const {},
    this.isStructured = false,
  });
}

class StreamedReply {
  final String raw;
  final StructuredReply parsed;

  const StreamedReply({
    required this.raw,
    required this.parsed,
  });

  String get visible => parsed.reply;
}

/// Converts model output into safe正文 + hidden metadata.
class StructuredReplyParser {
  StructuredReplyParser._();

  static const _minAffectionDelta = -0.3;
  static const _maxAffectionDelta = 0.8;
  static const _maxQuickReplies = 2;
  static const _maxQuickReplyChars = 20;

  static StructuredReply? parseJson(String raw) {
    final object = JsonUtils.extractJson(raw);
    if (object == null) return null;

    final replyValue = object['reply'];
    if (replyValue is! String) return null;

    final deltaValue = object['affection_delta'];
    final delta = deltaValue is num
        ? deltaValue.toDouble().clamp(_minAffectionDelta, _maxAffectionDelta)
        : null;
    final reason = object['affection_reason'] is String
        ? (object['affection_reason'] as String).trim()
        : '';
    final quickReplies = _parseQuickReplies(object['quick_replies']);
    final extra = <String, dynamic>{...object}
      ..remove('reply')
      ..remove('affection_delta')
      ..remove('affection_reason')
      ..remove('quick_replies');

    return StructuredReply(
      reply: _normalizeReplyText(replyValue).trim(),
      affectionDelta: delta,
      affectionReason: reason,
      quickReplies: quickReplies,
      extra: extra,
      isStructured: true,
    );
  }

  static StructuredReply parseAny(String raw) {
    final structured = parseJson(raw);
    if (structured != null) return structured;

    final partialReply = _extractPartialReply(raw);
    if (partialReply != null && partialReply.trim().isNotEmpty) {
      return StructuredReply(reply: _normalizeReplyText(partialReply).trim());
    }

    var content = raw.trim();
    double? delta;
    String reason = '';

    final deltaMatch = RegExp(
      r'Δ\s*([+\-±]?\d+\.?\d*)\s*([^\r\n]*)',
    ).firstMatch(content);
    if (deltaMatch != null) {
      delta = (double.tryParse(deltaMatch.group(1) ?? '') ?? 0.0)
          .clamp(_minAffectionDelta, _maxAffectionDelta);
      reason = (deltaMatch.group(2) ?? '').trim();
      content = content.replaceFirst(deltaMatch.group(0)!, '').trimRight();
    }

    List<String> quickReplies = const [];
    final quickMatch = RegExp(
      r'\[快捷回复\]\s*\n\s*(?:1|一)[\.、．:：]\s*(.+?)\s*\n\s*(?:2|二)[\.、．:：]\s*(.+?)(?:\s*$|\n\s*$)',
      multiLine: true,
    ).firstMatch(content);
    if (quickMatch != null) {
      quickReplies = _parseQuickReplies([
        quickMatch.group(1),
        quickMatch.group(2),
      ]);
      content = content.replaceFirst(quickMatch.group(0)!, '').trimRight();
    }

    return StructuredReply(
      reply: _normalizeReplyText(_stripJsonNoise(content)),
      affectionDelta: delta,
      affectionReason: reason,
      quickReplies: quickReplies,
    );
  }

  /// Returns only the visible reply portion while the model is still
  /// streaming. A malformed/incomplete envelope never leaks to the bubble.
  static String visibleText(String raw, {bool isFinal = false}) {
    final structured = parseJson(raw);
    if (structured != null) return structured.reply;

    final partial = _extractPartialReply(raw);
    if (partial != null) return partial;

    if (!isFinal) return '';
    return parseAny(raw).reply;
  }

  static List<String> _parseQuickReplies(dynamic value) {
    if (value is! List) return const [];
    final result = <String>[];
    for (final item in value) {
      if (item is! String) continue;
      final clean = _truncate(
          item.replaceAll(RegExp(r'\s+'), ' ').trim(), _maxQuickReplyChars);
      if (clean.isNotEmpty) result.add(clean);
      if (result.length >= _maxQuickReplies) break;
    }
    return result;
  }

  static String? _extractPartialReply(String raw) {
    final keyMatch = RegExp(r'"reply"\s*:\s*"').firstMatch(raw);
    if (keyMatch == null) return null;
    final start = keyMatch.end;
    var escaped = false;
    for (var i = start; i < raw.length; i++) {
      final char = raw[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (char == '"') {
        return _decodeJsonString(raw.substring(start, i));
      }
    }
    return _decodeJsonString(raw.substring(start));
  }

  static String _decodeJsonString(String fragment) {
    var value = fragment;
    if (value.endsWith(r'\')) value = value.substring(0, value.length - 1);
    try {
      return jsonDecode('"$value"') as String;
    } catch (_) {
      return value
          .replaceAll(r'\"', '"')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\r', '\r')
          .replaceAll(r'\t', '\t')
          .replaceAll(r'\\', r'\');
    }
  }

  /// Normalizes newline escape sequences that some models emit literally
  /// inside the JSON string instead of as JSON escapes.
  static String _normalizeReplyText(String value) {
    return value
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n');
  }

  /// Joins a continuation without gluing it to the previous paragraph.
  static String joinContinuation(String base, String continuation) {
    final left = base.replaceFirst(RegExp(r'[ \t]+$'), '');
    final right = continuation.replaceFirst(RegExp(r'^[ \t]+'), '');
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    if (left.endsWith('\n')) return '$left$right';
    return '$left\n\n$right';
  }

  static String _stripJsonNoise(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('```') && trimmed.endsWith('```')) {
      final lines = trimmed.split('\n');
      if (lines.length >= 3) {
        return lines.sublist(1, lines.length - 1).join('\n').trim();
      }
    }
    return trimmed;
  }

  static String _truncate(String value, int maxChars) {
    final runes = value.runes.toList();
    if (runes.length <= maxChars) return value;
    return String.fromCharCodes(runes.take(maxChars));
  }
}
