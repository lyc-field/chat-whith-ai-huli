import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/context_builder.dart';

void main() {
  group('ContextBuilder.shouldInjectRoleplayRule', () {
    test('injects the roleplay rule only on the second user message', () {
      expect(ContextBuilder.shouldInjectRoleplayRule(1), isFalse);
      expect(ContextBuilder.shouldInjectRoleplayRule(2), isTrue);
      expect(ContextBuilder.shouldInjectRoleplayRule(3), isFalse);
    });
  });
}
