/// Pure helpers for preparing chat requests.
class ChatRequestService {
  const ChatRequestService._();

  static double temperature({
    required bool affectionEnabled,
    required double affection,
  }) {
    if (!affectionEnabled) return 1.5;
    return 0.5 + (affection + 15) / 115 * 1.3;
  }

  static void addLengthDirectives(
    List<Map<String, dynamic>> contextMsgs, {
    required int minChars,
    required int maxChars,
  }) {
    var insertAt = contextMsgs.length;
    for (var i = 0; i < contextMsgs.length; i++) {
      final role = contextMsgs[i]['role'] as String?;
      if (role == 'user' || role == 'assistant') {
        insertAt = i;
        break;
      }
    }

    final directives = <Map<String, dynamic>>[];
    if (minChars > 0) {
      directives.add({
        'role': 'system',
        'content': '请严格遵守输出长度要求：回复不少于$minChars个汉字。若内容不足请继续补充，不要提前结束。',
      });
    }
    if (maxChars > 0) {
      directives.add({
        'role': 'system',
        'content': '请严格遵守输出长度要求：回复最多$maxChars个字符，禁止超出。',
      });
    }
    contextMsgs.insertAll(insertAt, directives);
  }
}
