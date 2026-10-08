import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/models/message.dart';
import 'package:chat_app/services/chat_memory_service.dart';

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
}
