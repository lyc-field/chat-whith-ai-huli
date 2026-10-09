import '../models/message.dart';
import '../models/segment_summary.dart';

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

  static String normalizeDiarySummary(String raw) {
    const headings = [
      '剧情总结',
      '事件记忆',
      '对用户的关系和心情',
      '待会要做什么',
    ];
    final text = raw.trim();
    final positions = <String, int>{};
    for (final heading in headings) {
      final index = text.indexOf(heading);
      if (index >= 0) positions[heading] = index;
    }
    if (positions.length < headings.length) {
      return [
        '剧情总结：${text.isEmpty ? '暂无' : text}',
        '事件记忆：',
        '对用户的关系和心情：',
        '待会要做什么：',
      ].join('\n\n');
    }

    final ordered = headings
        .map((heading) => (heading: heading, index: positions[heading]!))
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final sections = <String, String>{};
    for (var i = 0; i < ordered.length; i++) {
      final current = ordered[i];
      final end = i + 1 < ordered.length ? ordered[i + 1].index : text.length;
      final rawSection =
          text.substring(current.index + current.heading.length, end);
      sections[current.heading] =
          rawSection.replaceFirst(RegExp(r'^\s*[：:]\s*'), '').trim();
    }
    return headings
        .map((heading) => '$heading：${sections[heading] ?? ''}')
        .join('\n\n');
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
