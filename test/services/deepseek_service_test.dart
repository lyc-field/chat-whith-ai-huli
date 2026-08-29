import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/deepseek_service.dart';

void main() {
  group('DeepSeekService.estimateTokens', () {
    test('handles CJK text', () {
      final tok = DeepSeekService.estimateTokens('你好世界');
      expect(tok, greaterThanOrEqualTo(6));
    });

    test('handles ascii text', () {
      final tok = DeepSeekService.estimateTokens('hello world');
      expect(tok, inInclusiveRange(2, 4));
    });

    test('handles emoji without crashing and with stable count', () {
      final tok = DeepSeekService.estimateTokens('hi🙂');
      expect(tok, greaterThan(0));
    });
  });

  group('DeepSeekService.length conversion', () {
    test('charsToMaxTokens is tighter than old 2x rule', () {
      final v = DeepSeekService.charsToMaxTokens(100);
      expect(v, lessThan(200));
      expect(v, greaterThan(100));
    });

    test('charsToMaxTokens has minimum floor', () {
      final v = DeepSeekService.charsToMaxTokens(1);
      expect(v, 16);
    });
  });

  group('DeepSeekService.total estimate', () {
    test('estimateTotalTokens >= completion tokens', () {
      final context = <Map<String, dynamic>>[
        {'role': 'system', 'content': '你是助手'},
        {'role': 'user', 'content': '你好'},
      ];
      final total = DeepSeekService.estimateTotalTokens(context, '你好呀');
      final completionOnly = DeepSeekService.estimateTokens('你好呀');
      expect(total, greaterThan(completionOnly));
    });
  });
}
