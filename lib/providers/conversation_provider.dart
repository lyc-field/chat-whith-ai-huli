import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation.dart';
import '../services/database_service.dart';

class ConversationProvider extends ChangeNotifier {
  List<Conversation> _conversations = [];
  bool _loading = false;

  List<Conversation> get conversations => _conversations;
  bool get loading => _loading;

  Future<void> loadConversations() async {
    _loading = true;
    notifyListeners();
    _conversations = await DatabaseService.getConversations();
    _loading = false;
    notifyListeners();
  }

  Future<Conversation> createConversation({int initialAffection = 30, String mode = 'summary'}) async {
    final now = DateTime.now();
    final conv = Conversation(
      id: const Uuid().v4(),
      title: '新对话',
      createdAt: now,
      updatedAt: now,
      affection: initialAffection.clamp(-15, 100),
      mode: mode,
    );
    await DatabaseService.insertConversation(conv);
    _conversations.insert(0, conv);
    notifyListeners();
    return conv;
  }

  Future<void> deleteConversation(String id) async {
    await DatabaseService.deleteConversation(id);
    _conversations.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  Future<void> setConversationMode(String id, String mode) async {
    final conv = await DatabaseService.getConversation(id);
    final updated = conv.copyWith(mode: mode, updatedAt: DateTime.now());
    await DatabaseService.updateConversation(updated);
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _conversations[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> updateTitle(String id, String title) async {
    final conv = await DatabaseService.getConversation(id);
    final updated = conv.copyWith(title: title, updatedAt: DateTime.now());
    await DatabaseService.updateConversation(updated);
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _conversations[idx] = updated;
      notifyListeners();
    }
  }
}
