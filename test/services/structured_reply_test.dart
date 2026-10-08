import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/services/structured_reply.dart';

void main() {
  test('parses structured reply metadata and keeps extension fields', () {
    final result = StructuredReplyParser.parseJson('''
      {
        "reply": "我听见了，继续说吧。",
        "affection_delta": 0.3,
        "affection_reason": "用户愿意分享感受",
        "quick_replies": ["我想继续说", "换个轻松话题"],
        "future_field": {"kind": "scene"}
      }
    ''');

    expect(result, isNotNull);
    expect(result!.reply, '我听见了，继续说吧。');
    expect(result.affectionDelta, closeTo(0.3, 0.001));
    expect(result.affectionReason, '用户愿意分享感受');
    expect(result.quickReplies, ['我想继续说', '换个轻松话题']);
    expect(result.extra['future_field'], isA<Map<String, dynamic>>());
  });

  test('extracts JSON wrapped in markdown or surrounding text', () {
    final result = StructuredReplyParser.parseJson(
      '```json\n{"reply":"只显示正文","quick_replies":[]}\n```',
    );

    expect(result, isNotNull);
    expect(result!.reply, '只显示正文');
  });

  test('clamps affection metadata to the new -0.3..0.8 range', () {
    final low = StructuredReplyParser.parseJson(
      '{"reply":"x","affection_delta":-1.0}',
    );
    final high = StructuredReplyParser.parseJson(
      '{"reply":"x","affection_delta":2.0}',
    );

    expect(low!.affectionDelta, -0.3);
    expect(high!.affectionDelta, 0.8);
  });

  test('extracts正文 from a partial streaming JSON object', () {
    final visible = StructuredReplyParser.visibleText(
      '{"reply":"你好，今天过得怎么样？","affection_delta":',
    );

    expect(visible, '你好，今天过得怎么样？');
    expect(visible, isNot(contains('"reply"')));
    expect(visible, isNot(contains('affection_delta')));
  });

  test('malformed JSON never leaks its envelope to the user', () {
    final visible = StructuredReplyParser.visibleText(
      '{"reply":"正文内容","quick_replies":["A","B"]',
      isFinal: true,
    );
    final parsed = StructuredReplyParser.parseAny(
      '{"reply":"正文内容","quick_replies":["A","B"]',
    );

    expect(visible, '正文内容');
    expect(parsed.reply, '正文内容');
    expect(visible, isNot(contains('quick_replies')));
  });

  test('legacy Δ and quick-reply suffixes are hidden in fallback mode', () {
    final fallback = StructuredReplyParser.parseAny(
      '正文内容\nΔ+0.2 用户的关心\n[快捷回复]\n1. 继续\n2. 换话题',
    );

    expect(fallback.reply, '正文内容');
    expect(fallback.affectionDelta, closeTo(0.2, 0.001));
    expect(fallback.quickReplies, ['继续', '换话题']);
  });
}
