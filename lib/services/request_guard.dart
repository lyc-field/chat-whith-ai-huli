import 'package:uuid/uuid.dart';

/// Identifies one asynchronous chat operation and the state it belongs to.
class RequestToken {
  final int generation;
  final String id;
  final String? conversationId;
  final String? personaId;

  const RequestToken({
    required this.generation,
    required this.id,
    this.conversationId,
    this.personaId,
  });
}

/// Prevents late API/database callbacks from mutating a newer chat session.
class RequestGuard {
  int _generation = 0;

  RequestToken begin({String? conversationId, String? personaId}) {
    _generation++;
    return RequestToken(
      generation: _generation,
      id: const Uuid().v4(),
      conversationId: conversationId,
      personaId: personaId,
    );
  }

  void invalidate() {
    _generation++;
  }

  bool isCurrent(
    RequestToken token, {
    String? conversationId,
    String? personaId,
  }) {
    if (token.generation != _generation) return false;
    if (conversationId != null &&
        token.conversationId != null &&
        token.conversationId != conversationId) {
      return false;
    }
    if (personaId != null &&
        token.personaId != null &&
        token.personaId != personaId) {
      return false;
    }
    return true;
  }
}
