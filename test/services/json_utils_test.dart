import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/json_utils.dart';

void main() {
  group('JsonUtils.extractJson', () {
    test('parses simple JSON directly', () {
      final result = JsonUtils.extractJson('{"a": 1, "b": "hello"}');
      expect(result, isNotNull);
      expect(result!['a'], 1);
      expect(result['b'], 'hello');
    });

    test('parses JSON with surrounding text', () {
      final result = JsonUtils.extractJson(
        'Here is some text before {"key": "value", "num": 42} and after',
      );
      expect(result, isNotNull);
      expect(result!['key'], 'value');
      expect(result['num'], 42);
    });

    test('parses nested JSON objects correctly', () {
      final result = JsonUtils.extractJson(
        'Output: {"outer": {"inner": [1, 2, 3]}, "flag": true}',
      );
      expect(result, isNotNull);
      expect(result!['flag'], true);
      expect(result['outer'], {'inner': [1, 2, 3]});
    });

    test('handles unicode in JSON content', () {
      final result = JsonUtils.extractJson('{"msg": "你好世界"}');
      expect(result, isNotNull);
      expect(result!['msg'], '你好世界');
    });

    test('returns null for text without JSON', () {
      final result = JsonUtils.extractJson('This is just plain text, no JSON here.');
      expect(result, isNull);
    });

    test('handles text with only an opening brace', () {
      final result = JsonUtils.extractJson('Text with { but no closing');
      expect(result, isNull);
    });

    test('handles array as fallback (not a Map)', () {
      final result = JsonUtils.extractJson('[1, 2, 3]');
      // Direct parse fails (List, not Map), no { found → returns null
      expect(result, isNull);
    });

    test('handles empty string', () {
      final result = JsonUtils.extractJson('');
      expect(result, isNull);
    });

    test('handles JSON with escaped characters', () {
      final result = JsonUtils.extractJson(r'{"path": "C:\\Users\\test", "quote": "say \"hi\""}');
      expect(result, isNotNull);
      expect(result!['path'], r'C:\Users\test');
    });
  });
}
