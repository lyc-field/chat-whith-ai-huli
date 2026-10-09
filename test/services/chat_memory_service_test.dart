import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/message.dart';
import 'package:chat_app/services/chat_memory_service.dart';
import 'package:chat_app/models/segment_summary.dart';

void main() {
  test('selects only active non-empty messages for the next archive', () {
    final messages = [
      Message(conversationId: 'c', role: 'user', content: 'archived')
          .copyWith(segmentIndex: 0),
      Message(conversationId: 'c', role: 'assistant', content: ''),
      Message(conversationId: 'c', role: 'user', content: 'one'),
      Message(conversationId: 'c', role: 'assistant', content: 'two'),
      Message(conversationId: 'c', role: 'user', content: 'three'),
    ];

    final selected = ChatMemoryService.selectArchive(messages, count: 2);

    expect(selected.map((m) => m.content), ['one', 'two']);
  });

  test('formats archive text with stable role labels', () {
    final messages = [
      Message(conversationId: 'c', role: 'user', content: '你好'),
      Message(conversationId: 'c', role: 'assistant', content: '你好呀'),
    ];

    expect(
      ChatMemoryService.formatArchiveText(messages),
      '用户: 你好\nAI: 你好呀',
    );
  });

  test(
      'keeps the latest summaries and selects older summaries relevant to the query',
      () {
    final summaries = [
      SegmentSummary(conversationId: 'c', segmentIndex: 0, content: '在图书馆找到地图'),
      SegmentSummary(conversationId: 'c', segmentIndex: 1, content: '讨论了天气和晚餐'),
      SegmentSummary(
          conversationId: 'c', segmentIndex: 2, content: '回到图书馆继续寻找地图'),
      SegmentSummary(conversationId: 'c', segmentIndex: 3, content: '最近准备出发'),
    ];

    final selected = ChatMemoryService.selectRelevantSegments(
      summaries,
      query: '地图',
      latestCount: 1,
      maxRelevant: 1,
    );

    expect(selected.map((s) => s.segmentIndex), [2, 3]);
  });

  test('calculates a summary range from the actual archived user rounds', () {
    final messages = [
      Message(conversationId: 'c', role: 'user', content: 'old')
          .copyWith(segmentIndex: 0),
      Message(conversationId: 'c', role: 'assistant', content: 'old reply')
          .copyWith(segmentIndex: 0),
      Message(conversationId: 'c', role: 'user', content: 'new one')
          .copyWith(segmentIndex: 1),
      Message(conversationId: 'c', role: 'assistant', content: 'new reply')
          .copyWith(segmentIndex: 1),
      Message(conversationId: 'c', role: 'user', content: 'new two')
          .copyWith(segmentIndex: 1),
      Message(conversationId: 'c', role: 'assistant', content: 'new reply')
          .copyWith(segmentIndex: 1)
    ];

    final range = ChatMemoryService.roundRangeForArchive(messages, 1);

    expect(range.start, 2);
    expect(range.end, 3);
  });

  test('parses compact JSON diary sections and preserves natural role text',
      () {
    final raw = '''
{"plot":"我陪用户走过安静的长廊，话题从旧书转到了彼此都在意的未来。","events":"我们约好下次继续寻找那本失落的书，也记下了线索藏在钟楼附近。","relation":"听见用户愿意陪我继续寻找，我心里踏实了些，也更愿意把这件事交给我们一起完成。","next":"等用户下次回来，我会先带他去钟楼，再把今天记下的线索一一核对。"}
''';

    final normalized = ChatMemoryService.normalizeDiarySummary(raw);

    expect(ChatMemoryService.isValidDiarySummary(raw), isTrue);
    expect(normalized, contains('剧情总结：'));
    expect(normalized, contains('事件记忆：'));
    expect(normalized, contains('对用户的关系和心情：'));
    expect(normalized, contains('待会要做什么：'));
  });

  test('rejects one-section output instead of stuffing it into plot', () {
    const raw = '{"plot":"我只记住了刚才发生的事情，但其他内容都没有整理出来。"}';

    expect(ChatMemoryService.isValidDiarySummary(raw), isFalse);
    expect(ChatMemoryService.normalizeDiarySummary(raw), contains('剧情总结：'));
    expect(ChatMemoryService.normalizeDiarySummary(raw), isNot(contains('暂无')));
  });

  test('omits optional sections that are too short and truncates long sections',
      () {
    final longText = '我'.padRight(140, '啊');
    final raw = '{"plot":"${'我和用户一起确认了接下来的安排，并把重要线索重新整理了一遍。'}",'
        '"events":"太短",'
        '"relation":"${'我因为用户愿意耐心听我说完而感到安心，也更愿意把真实想法告诉他。'}",'
        '"next":"$longText"}';

    final normalized = ChatMemoryService.normalizeDiarySummary(raw);
    final sections = ChatMemoryService.parseDiarySummary(raw);

    expect(sections.containsKey('events'), isFalse);
    expect(sections['next']!.runes.length, 120);
    expect(normalized, contains('剧情总结：'));
    expect(normalized, contains('对用户的关系和心情：'));
    expect(normalized, contains('待会要做什么：'));
  });

  test('selects only the original messages belonging to one summary segment',
      () {
    final messages = [
      Message(conversationId: 'c', role: 'user', content: 'a')
          .copyWith(segmentIndex: 0),
      Message(conversationId: 'c', role: 'assistant', content: 'b')
          .copyWith(segmentIndex: 0),
      Message(conversationId: 'c', role: 'user', content: 'c')
          .copyWith(segmentIndex: 1),
    ];

    expect(
      ChatMemoryService.selectSegmentMessages(messages, 0)
          .map((message) => message.content),
      ['a', 'b'],
    );
  });
}
