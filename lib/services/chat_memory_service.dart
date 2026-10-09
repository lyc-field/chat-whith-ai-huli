import '../models/message.dart';
import '../models/segment_summary.dart';
import 'json_utils.dart';

/// Pure message selection/formatting helpers used by the memory pipeline.
class ChatMemoryService {
  const ChatMemoryService._();

  static List<Message> selectArchive(
    List<Message> messages, {
    required int count,
  }) {
    final active = messages
        .where((message) =>
            message.content.isNotEmpty && message.segmentIndex == null)
        .toList();
    return active.take(count).toList();
  }

  static String formatArchiveText(Iterable<Message> messages) {
    return messages
        .map((message) =>
            '${message.role == 'user' ? '用户' : 'AI'}: ${message.content}')
        .join('\n');
  }

  static List<Message> selectSegmentMessages(
    List<Message> messages,
    int segmentIndex,
  ) {
    return messages
        .where((message) =>
            message.segmentIndex == segmentIndex &&
            message.content.trim().isNotEmpty)
        .toList();
  }

  /// Keeps the newest summaries for continuity and adds older summaries whose
  /// content is most related to the current user message.
  static List<SegmentSummary> selectRelevantSegments(
    List<SegmentSummary> segments, {
    String query = '',
    int latestCount = 2,
    int maxRelevant = 3,
  }) {
    if (segments.isEmpty) return const [];
    final ordered = [...segments]
      ..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
    final latestStart = (ordered.length - latestCount).clamp(0, ordered.length);
    final latest = ordered.sublist(latestStart);
    final latestIds = latest.map((s) => s.id).toSet();
    final older = ordered.where((s) => !latestIds.contains(s.id)).toList();
    final ranked = older
        .map((segment) => (
              segment: segment,
              score: _summaryScore(segment.content, query),
            ))
        .where((item) => item.score > 0)
        .toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0
            ? score
            : b.segment.segmentIndex.compareTo(a.segment.segmentIndex);
      });
    final relevant = ranked
        .take(maxRelevant)
        .map((item) => item.segment)
        .toList()
      ..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
    return [...relevant, ...latest];
  }

  static ({int start, int end}) roundRangeForArchive(
    List<Message> messages,
    int segmentIndex,
  ) {
    final previousRounds = messages
        .where((message) =>
            message.role == 'user' &&
            message.content.trim().isNotEmpty &&
            message.segmentIndex != null &&
            message.segmentIndex! < segmentIndex)
        .length;
    final archivedRounds = messages
        .where((message) =>
            message.role == 'user' &&
            message.content.trim().isNotEmpty &&
            message.segmentIndex == segmentIndex)
        .length;
    final count = archivedRounds == 0 ? 8 : archivedRounds;
    return (start: previousRounds + 1, end: previousRounds + count);
  }

  static const _diaryKeys = ['plot', 'events', 'relation', 'next'];
  static const _diaryLabels = {
    'plot': '剧情总结',
    'events': '事件记忆',
    'relation': '对用户的关系和心情',
    'next': '待会要做什么',
  };

  /// Parses the compact model envelope and keeps only meaningful sections.
  /// A section is optional, but every emitted section is 20–120 characters.
  static Map<String, String> parseDiarySummary(String raw) {
    final object = JsonUtils.extractJson(raw);
    final values = <String, dynamic>{...?object};
    final aliases = {
      '剧情总结': 'plot',
      '事件记忆': 'events',
      '对用户的关系和心情': 'relation',
      '待会要做什么': 'next',
    };
    for (final entry in aliases.entries) {
      if (values[entry.key] != null && values[entry.value] == null) {
        values[entry.value] = values[entry.key];
      }
    }

    final sections = <String, String>{};
    for (final key in _diaryKeys) {
      final value = values[key];
      if (value is! String) continue;
      final clean = _cleanDiaryText(value);
      if (_isDiarySectionLengthValid(clean)) {
        sections[key] = _truncateRunes(clean, 120);
      }
    }
    return sections;
  }

  static bool isValidDiarySummary(String raw) {
    return parseDiarySummary(raw).length >= 2;
  }

  static String normalizeDiarySummary(String raw) {
    final sections = parseDiarySummary(raw);
    if (sections.isEmpty) return raw.trim();
    return _diaryKeys
        .where(sections.containsKey)
        .map((key) => '${_diaryLabels[key]}：${sections[key]}')
        .join('\n\n');
  }

  static String _cleanDiaryText(String value) {
    return value
        .replaceAll(RegExp(r'```(?:json)?|```'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isDiarySectionLengthValid(String value) {
    final length = value.runes.length;
    return length >= 20;
  }

  static String _truncateRunes(String value, int maxLength) {
    final runes = value.runes.toList();
    if (runes.length <= maxLength) return value;
    return String.fromCharCodes(runes.take(maxLength));
  }

  static int _summaryScore(String content, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedContent = content.trim().toLowerCase();
    if (normalizedQuery.isEmpty || normalizedContent.isEmpty) return 0;
    var score = 0;
    if (normalizedContent.contains(normalizedQuery)) score += 3;
    final queryTokens = _tokens(normalizedQuery);
    final contentTokens = _tokens(normalizedContent);
    score += queryTokens.intersection(contentTokens).length;
    return score;
  }

  static Set<String> _tokens(String value) {
    final tokens = <String>{};
    final words = RegExp(r'[a-z0-9]+', caseSensitive: false)
        .allMatches(value)
        .map((match) => match.group(0)!)
        .where((word) => word.length > 1);
    tokens.addAll(words);
    for (final rune in value.runes) {
      if ((rune >= 0x4e00 && rune <= 0x9fff) ||
          (rune >= 0x3400 && rune <= 0x4dbf)) {
        tokens.add(String.fromCharCode(rune));
      }
    }
    return tokens;
  }
}
