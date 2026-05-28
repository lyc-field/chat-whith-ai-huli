import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

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
      contextMessages: messages
          .map((m) => {'role': m.role, 'content': m.content})
          .toList(),
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
    double temperature = 1.0,
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
        'temperature': temperature,
      });

    final response = await http.Client().send(request);
    final buffer = StringBuffer();

    try {
      await for (final chunk
          in response.stream.transform(utf8.decoder).timeout(const Duration(seconds: 30))) {
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
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                if (content != null && content.isNotEmpty) {
                  buffer.write(content);
                  onToken(content);
                }
              }
            } catch (_) { /* skip malformed SSE chunk */ }
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
        throw Exception('API error ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      return choices[0]['message']['content'] as String;
    } on FormatException catch (e) {
      throw Exception('JSON解析失败: $e');
    } on Exception {
      rethrow;
    }
  }

  /// Non-streaming chat with raw prompt strings. Used by unconscious LLM.
  Future<String> chatRaw(String userPrompt, String systemPrompt, {int maxTokens = 200}) async {
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
        throw Exception('API error ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>;
      return choices[0]['message']['content'] as String;
    } on FormatException catch (e) {
      throw Exception('JSON解析失败: $e');
    } on Exception {
      rethrow;
    }
  }

}
