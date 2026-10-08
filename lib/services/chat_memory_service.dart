import '../models/message.dart';

/// Pure message selection/formatting helpers used by the memory pipeline.
class ChatMemoryService {
  const ChatMemoryService._();

  static List<Message> selectArchive(
    List<Message> messages, {
    required int count,
  }) {
    final active = messages
        .where((message) =>
            message.content.isNotEmpty && message.segmentIndex == null)
        .toList();
    return active.take(count).toList();
  }

  static String formatArchiveText(Iterable<Message> messages) {
    return messages
        .map((message) =>
            '${message.role == 'user' ? '用户' : 'AI'}: ${message.content}')
        .join('\n');
  }
}
