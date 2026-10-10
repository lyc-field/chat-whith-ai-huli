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

  /// Selects whole conversation rounds by counting user messages, not raw
  /// message rows. Assistant continuations remain attached to their round.
  static List<Message> selectArchiveRounds(
    List<Message> messages, {
    required int roundCount,
  }) {
    if (roundCount <= 0) return const [];
    final active = messages
        .where((message) =>
            message.content.trim().isNotEmpty && message.segmentIndex == null)
        .toList();
    final selected = <Message>[];
    var selectedRounds = 0;
    for (final message in active) {
      if (message.role == 'user' && selectedRounds >= roundCount) break;
      selected.add(message);
      if (message.role == 'user') selectedRounds++;
    }
    return selected;
  }

  static int countUserRounds(Iterable<Message> messages) {
    return messages
        .where((message) =>
            message.role == 'user' && message.content.trim().isNotEmpty)
        .length;
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
    final object = JsonUtils.extractJson(raw);
    if (object == null) return false;
    if (object.isEmpty) return true;
    return object.keys.any(_diaryKeys.contains) ||
        object.keys.any(_diaryLabels.containsKey);
  }

  static String normalizeDiarySummary(String raw) {
    final sections = parseDiarySummary(raw);
    if (sections.isEmpty) return '';
    return _diaryKeys
        .where(sections.containsKey)
        .map((key) => '${_diaryLabels[key]}：${sections[key]}')
        .join('\n\n');
  }

  /// Returns the two immediately preceding summaries in chronological order.
  /// Manual edits don't change the selection window, but are explicitly marked
  /// as user-confirmed within that window.
  static List<SegmentSummary> selectSummaryReferences(
    List<SegmentSummary> summaries, {
    required int beforeSegmentIndex,
    int limit = 2,
  }) {
    final preceding = summaries
        .where((summary) => summary.segmentIndex < beforeSegmentIndex)
        .toList()
      ..sort((a, b) => b.segmentIndex.compareTo(a.segmentIndex));
    final selected = preceding.take(limit).toList()
      ..sort((a, b) => a.segmentIndex.compareTo(b.segmentIndex));
    return selected;
  }

  static String formatSummaryReferences(
    List<SegmentSummary> references,
  ) {
    if (references.isEmpty) return '';
    final entries = references
        .where((summary) => summary.content.trim().isNotEmpty)
        .map((summary) {
      final status =
          summary.manuallyEdited ? '【用户手动确认，最高优先级参考】' : '【AI 旧总结，仅供参考】';
      return '$status ${summary.content.trim()}';
    }).toList();
    if (entries.isEmpty) return '';
    return [
      '最近两条总结参考（只作为背景，不要照抄）：',
      ...entries,
      '旧总结仅供参考，当前八轮对话为准；若与当前原始对话冲突，以当前内容为准，绝不修改旧总结。仍然重要的旧事实可简短延续，不要重复过多；若角色自然察觉到明显矛盾，可以在关系或计划内容中向用户确认。',
    ].join('\n');
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
