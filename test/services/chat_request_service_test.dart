import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/chat_request_service.dart';

void main() {
  test('calculates temperature from affection only when affection is enabled', () {
    expect(
      ChatRequestService.temperature(
        affectionEnabled: true,
        affection: -15,
      ),
      closeTo(0.5, 0.001),
    );
    expect(
      ChatRequestService.temperature(
        affectionEnabled: true,
        affection: 100,
      ),
      closeTo(1.8, 0.001),
    );
    expect(
      ChatRequestService.temperature(
        affectionEnabled: false,
        affection: 30,
      ),
      1.5,
    );
  });

  test('adds minimum and maximum output directives before chat messages', () {
    final context = <Map<String, dynamic>>[
      {'role': 'system', 'content': 'persona'},
      {'role': 'user', 'content': 'hello'},
    ];

    ChatRequestService.addLengthDirectives(
      context,
      minChars: 20,
      maxChars: 80,
    );

    expect(context[1]['role'], 'system');
    expect(context[1]['content'], contains('不少于20'));
    expect(context[2]['role'], 'system');
    expect(context[2]['content'], contains('最多80'));
  });
}
