import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ai_persona.dart';
import '../services/database_service.dart';

class PersonaProvider extends ChangeNotifier {
  String? _conversationId;
  List<AIPersona> _personas = [];
  int _currentIndex = 0;
  Timer? _autoSaveTimer;

  List<AIPersona> get personas => _personas;
  int get currentIndex => _currentIndex;

  AIPersona? get currentPersona =>
      _personas.isNotEmpty ? _personas[_currentIndex] : null;

  /// Load personas for a specific conversation. Does NOT create default.
  Future<void> loadPersonas(String conversationId) async {
    _conversationId = conversationId;
    _personas = await DatabaseService.getAIPersonas(conversationId);
    if (_currentIndex >= _personas.length) {
      _currentIndex = 0;
    }
    notifyListeners();
  }

  /// Create a pending default persona in memory (no DB save yet).
  /// Used for new chats before the conversation ID is available.
  void initPendingDefault() {
    _conversationId = '';
    _personas = [AIPersona(name: '默认角色', conversationId: '')];
    _currentIndex = 0;
    notifyListeners();
  }

  /// Replace the current pending persona list with a persisted one.
  /// Used when a new conversation is created and the pending personas get a real ID.
  void replaceWithPersisted(List<AIPersona> persisted, String conversationId) {
    _conversationId = conversationId;
    _personas = persisted;
    _currentIndex = 0;
    notifyListeners();
  }

  /// Create a default persona if none exist (for new conversations).
  Future<void> ensureDefaultPersona() async {
    if (_personas.isEmpty && _conversationId != null) {
      final defaultPersona = AIPersona(
        name: '默认角色',
        conversationId: _conversationId!,
      );
      await DatabaseService.insertAIPersona(defaultPersona);
      _personas = [defaultPersona];
      _currentIndex = 0;
      notifyListeners();
    }
  }

  /// Nuke current state — called when switching to a new conversation.
  void prepareForConversation(String conversationId) {
    _autoSaveTimer?.cancel();
    _conversationId = conversationId;
    _personas = [];
    _currentIndex = 0;
  }

  /// Switch to a different persona by index.
  void selectPersona(int index) {
    if (index >= 0 && index < _personas.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// Create a new persona with the given name (fields start empty).
  Future<void> createPersona(String name) async {
    if (_conversationId == null) return;
    final persona = AIPersona(
      name: name.trim().isEmpty ? '未命名角色' : name.trim(),
      conversationId: _conversationId!,
    );
    await DatabaseService.insertAIPersona(persona);
    _personas.add(persona);
    _currentIndex = _personas.length - 1;
    notifyListeners();
  }

  /// Import a persona from an external source. Assigns current conversationId.
  Future<void> importPersona(AIPersona template) async {
    if (_conversationId == null) return;
    final persona = AIPersona(
      conversationId: _conversationId!,
      name: template.name,
      personality: template.personality,
      habits: template.habits,
      appearance: template.appearance,
      background: template.background,
    );
    await DatabaseService.insertAIPersona(persona);
    _personas.add(persona);
    notifyListeners();
  }

  /// Delete a persona. Cannot delete the last one — it becomes empty default.
  Future<void> deletePersona(String id) async {
    if (_conversationId == null) return;
    if (_personas.length <= 1) {
      final blank = AIPersona(name: '默认角色', conversationId: _conversationId!);
      await DatabaseService.insertAIPersona(blank);
      await DatabaseService.deleteAIPersona(id);
      _personas = [blank];
      _currentIndex = 0;
    } else {
      await DatabaseService.deleteAIPersona(id);
      _personas.removeWhere((p) => p.id == id);
      if (_currentIndex >= _personas.length) {
        _currentIndex = _personas.length - 1;
      }
    }
    notifyListeners();
  }

  /// Debounced auto-save for persona fields.
  void autoSave(AIPersona persona) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      await DatabaseService.updateAIPersona(persona);
    });
  }

  /// Immediate save (for when leaving the page).
  Future<void> saveImmediately(AIPersona persona) async {
    _autoSaveTimer?.cancel();
    await DatabaseService.updateAIPersona(persona);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
