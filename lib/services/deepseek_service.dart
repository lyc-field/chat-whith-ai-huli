import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

class ChatUsage {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  const ChatUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });
}

class DeepSeekService {
  final String apiKey;
  final String endpoint;
  final String model;

  DeepSeekService({
    required this.apiKey,
    this.endpoint = 'https://api.deepseek.com/v1/chat/completions',
    this.model = 'deepseek-v4-flash',
  });

  Future<String> streamChat({
    required List<Message> messages,
    required void Function(String token) onToken,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    return streamChatRaw(
      contextMessages:
          messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
      onToken: onToken,
      onDone: onDone,
      onError: onError,
    );
  }

  Future<String> streamChatRaw({
    required List<Map<String, dynamic>> contextMessages,
    required void Function(String token) onToken,
    void Function()? onDone,
    void Function(String error)? onError,
    void Function(ChatUsage usage)? onUsage,
    double temperature = 1.0,
    int? maxTokens,
  }) async {
    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      })
      ..body = jsonEncode({
        'model': model,
        'messages': contextMessages,
        'stream': true,
        'stream_options': {'include_usage': true},
        'temperature': temperature,
        if (maxTokens != null && maxTokens > 0) 'max_tokens': maxTokens,
      });

    final response = await http.Client().send(request);
    final buffer = StringBuffer();

    try {
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 30))) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') {
              onDone?.call();
              return buffer.toString();
            }
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final choices = json['choices'] as List<dynamic>?;
              final usage = json['usage'] as Map<String, dynamic>?;
              if (usage != null && onUsage != null) {
                int? toInt(dynamic v) => (v as num?)?.toInt();
                onUsage(ChatUsage(
                  promptTokens: toInt(usage['prompt_tokens']),
                  completionTokens: toInt(usage['completion_tokens']),
                  totalTokens: toInt(usage['total_tokens']),
                ));
              }
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  buffer.write(content);
                  onToken(content);
                }
              }
            } catch (_) {/* skip malformed SSE chunk */}
          }
        }
      }
    } on TimeoutException {
      // Silently exit on timeout, return whatever we received
    } catch (e) {
      final error = e.toString();
      if (onError != null) onError(error);
      if (buffer.isEmpty) rethrow;
    }

    return buffer.toString();
  }

  Future<String> chat(List<Message> messages) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(),
          'stream': false,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'API error ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
      }

      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      return choices[0]['message']['content'] as String;
    } on FormatException catch (e) {
      throw Exception('JSON解析失败: $e');
    } on Exception {
      rethrow;
    }
  }

  /// Non-streaming chat with raw prompt strings. Used by unconscious LLM.
  Future<String> chatRaw(String userPrompt, String systemPrompt,
      {int maxTokens = 200}) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'stream': false,
          'temperature': 0.3,
          'max_tokens': maxTokens,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'API error ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
      }

      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      return choices[0]['message']['content'] as String;
    } on FormatException catch (e) {
      throw Exception('JSON解析失败: $e');
    } on Exception {
      rethrow;
    }
  }

  /// Roughly estimate token count from text.
  /// Chinese/CJK characters ≈ 1.5 tokens each, other chars ≈ 0.25 tokens each.
  static int estimateTokens(String text) {
    int cjk = 0;
    int other = 0;
    for (final c in text.runes) {
      if ((c >= 0x4E00 && c <= 0x9FFF) ||
          (c >= 0x3400 && c <= 0x4DBF) ||
          (c >= 0xF900 && c <= 0xFAFF) ||
          (c >= 0x20000 && c <= 0x2CEAF) ||
          (c >= 0x2F800 && c <= 0x2FA1F)) {
        cjk++;
      } else if (c > 0x7F) {
        cjk++;
      } else {
        other++;
      }
    }
    return (cjk * 1.5 + other * 0.25).ceil();
  }

  /// Rough estimate for prompt tokens from context messages.
  static int estimateContextTokens(List<Map<String, dynamic>> contextMessages) {
    int sum = 0;
    for (final msg in contextMessages) {
      final content = (msg['content'] as String?) ?? '';
      // Add small structural overhead per chat message.
      sum += estimateTokens(content) + 4;
    }
    return sum;
  }

  /// Total estimated tokens for a single reply turn (input + output).
  static int estimateTotalTokens(
      List<Map<String, dynamic>> contextMessages, String completion) {
    return estimateContextTokens(contextMessages) + estimateTokens(completion);
  }

  /// Convert user-specified max character count to a safe max_tokens value.
  /// Uses a tighter multiplier to better match visible character limits.
  static int charsToMaxTokens(int chars) {
    if (chars <= 0) return 0;
    final v = (chars * 1.35).ceil();
    if (v < 16) return 16;
    if (v > 8192) return 8192;
    return v;
  }
}
