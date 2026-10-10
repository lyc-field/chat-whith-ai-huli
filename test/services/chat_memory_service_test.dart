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

  test('selects eight user-message rounds including assistant continuations',
      () {
    final messages = <Message>[];
    for (var round = 1; round <= 9; round++) {
      messages.add(Message(
        conversationId: 'c',
        role: 'user',
        content: 'user $round',
      ));
      messages.add(Message(
        conversationId: 'c',
        role: 'assistant',
        content: 'assistant $round',
      ));
      if (round == 3) {
        messages.add(Message(
          conversationId: 'c',
          role: 'assistant',
          content: 'assistant continuation',
        ));
      }
    }

    final selected = ChatMemoryService.selectArchiveRounds(
      messages,
      roundCount: 8,
    );

    expect(selected.where((message) => message.role == 'user').length, 8);
    expect(selected.last.content, 'assistant 8');
    expect(
        selected.any((message) => message.content == 'assistant continuation'),
        isTrue);
    expect(selected.any((message) => message.content == 'user 9'), isFalse);
  });

  test('counts only user rounds with an assistant response', () {
    final messages = [
      Message(conversationId: 'c', role: 'user', content: 'answered'),
      Message(conversationId: 'c', role: 'assistant', content: 'reply'),
      Message(conversationId: 'c', role: 'user', content: 'pending'),
    ];

    expect(ChatMemoryService.countUserRounds(messages), 1);
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

  test('accepts one valid section and leaves an empty result empty', () {
    const oneSection = '{"relation":"我听见用户愿意陪我继续走下去，心里比刚才安稳，也更愿意相信这段关系。"}';

    expect(ChatMemoryService.isValidDiarySummary(oneSection), isTrue);
    expect(ChatMemoryService.normalizeDiarySummary(oneSection),
        startsWith('对用户的关系和心情：'));
    expect(ChatMemoryService.normalizeDiarySummary('{}'), isEmpty);
    expect(ChatMemoryService.isValidDiarySummary('{}'), isTrue);
    expect(
        ChatMemoryService.isValidDiarySummary('{"unknown":"value"}'), isFalse);
  });

  test('accepts supported Chinese field names from model output', () {
    const raw = '{"剧情总结":"我和用户整理了钟楼附近的线索，也决定明天继续沿着旧地图寻找入口。"}';

    expect(ChatMemoryService.isValidDiarySummary(raw), isTrue);
    expect(ChatMemoryService.normalizeDiarySummary(raw), startsWith('剧情总结：'));
  });

  test(
      'uses the previous two summaries and marks manual edits as trusted references',
      () {
    final summaries = [
      SegmentSummary(
        conversationId: 'c',
        segmentIndex: 0,
        content: '用户确认的旧约定仍然有效，我们之后会一起回到钟楼继续寻找线索。',
        manuallyEdited: true,
      ),
      SegmentSummary(
        conversationId: 'c',
        segmentIndex: 1,
        content: '最近讨论了晚餐和天气，没有形成持续有效的约定。',
        manuallyEdited: true,
      ),
      SegmentSummary(
        conversationId: 'c',
        segmentIndex: 2,
        content: '最新发生的事情是我们暂时改去图书馆查看线索。',
      ),
      SegmentSummary(
        conversationId: 'c',
        segmentIndex: 3,
        content: '当前总结，不应被当作上一轮参考。',
      ),
    ];

    final references = ChatMemoryService.selectSummaryReferences(
      summaries,
      beforeSegmentIndex: 3,
      limit: 2,
    );

    expect(references.map((summary) => summary.segmentIndex), [1, 2]);
    final prompt = ChatMemoryService.formatSummaryReferences(references);
    expect(prompt, contains('用户确认'));
    expect(prompt, contains('最高优先级'));
    expect(prompt, contains('当前八轮对话为准'));
    expect(prompt, isNot(contains('当前总结，不应')));
    expect(prompt, isNot(contains('segmentIndex')));
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
