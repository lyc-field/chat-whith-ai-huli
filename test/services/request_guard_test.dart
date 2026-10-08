import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/request_guard.dart';

void main() {
  test('a request becomes stale after invalidation', () {
    final guard = RequestGuard();
    final token = guard.begin(conversationId: 'conversation-1', personaId: 'persona-1');

    expect(guard.isCurrent(token), isTrue);

    guard.invalidate();

    expect(guard.isCurrent(token), isFalse);
  });

  test('starting a newer request invalidates the previous request', () {
    final guard = RequestGuard();
    final first = guard.begin(conversationId: 'conversation-1', personaId: 'persona-1');
    final second = guard.begin(conversationId: 'conversation-1', personaId: 'persona-1');

    expect(guard.isCurrent(first), isFalse);
    expect(guard.isCurrent(second), isTrue);
  });

  test('a token is stale when conversation or persona no longer matches', () {
    final guard = RequestGuard();
    final token = guard.begin(conversationId: 'conversation-1', personaId: 'persona-1');

    expect(
      guard.isCurrent(token, conversationId: 'conversation-2', personaId: 'persona-1'),
      isFalse,
    );
    expect(
      guard.isCurrent(token, conversationId: 'conversation-1', personaId: 'persona-2'),
      isFalse,
    );
  });
}
