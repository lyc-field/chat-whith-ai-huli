import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/segment_summary.dart';
import '../models/emotion_state.dart';
import '../models/ai_persona.dart';
import '../services/deepseek_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/emotion_service.dart';
import '../services/context_builder.dart';
import '../services/knowledge_base.dart';
import '../services/affection_manager.dart';
import '../services/emotion_state_repository.dart';
import '../services/request_guard.dart';
import '../services/chat_request_service.dart';
import '../services/chat_memory_service.dart';
import '../services/structured_reply.dart';
import '../services/content_safety_service.dart';
import 'conversation_provider.dart';
import 'persona_provider.dart';

class ChatProvider extends ChangeNotifier {
  // Memory thresholds: 20 rounds (40 msgs) max, archive 8 rounds (16 msgs) at a time
  static const maxActiveMessages = 40;
  static const triggerArchiveAt = 40;
  static const archiveCount = 16;
  ConversationProvider _convProvider;
  final PersonaProvider? _personaProvider;
  DeepSeekService? _service; // chat model
  String _providerType = 'deepseek';
  final AffectionManager _affm = AffectionManager();
  final RequestGuard _requestGuard = RequestGuard();
  bool _affectionEnabled = true;
  String? _currentConvId;
  String? _systemPrompt;
  String? _userPersona;
  String? _worldBackground;
  String? _openingLine;
  String? _chatBackground;
  bool _eroticMode = false;
  String _mode = 'summary';
  List<Message> _messages = [];
  List<SegmentSummary> _segments = [];
  bool _isPending = false;
  String _streamingContent = '';
  String? _error;

  bool _showSummaryPrompt = false;
  int? _pendingSummaryIndex;

  // Quick reply
  List<String> _quickReplies = [];
  int? _quickReplyMessageIndex;

  // Auto-continue mode (AI keeps talking)
  bool _isContinuing = false;
  bool _reasoningMode = false;

  static const String _deepSeekDefaultModel = 'deepseek-v4-flash';
  static const String _deepSeekProModel = 'deepseek-v4-pro';
  String _deepSeekModel = _deepSeekDefaultModel;

  // Recall limit
  static const _maxRecalls = 3;
  int _recallCount = 0;
  Map<String, String> _emotionTemplateLibrary = {};
  String? _emotionTemplateSignature;


  List<Message> get messages => _messages;
  List<SegmentSummary> get segments => _segments;
  bool get isPending => _isPending;
  String get streamingContent => _streamingContent;
  String? get error => _error;
  String? get currentConvId => _currentConvId;
  String? get systemPrompt => _systemPrompt;
  String? get userPersona => _userPersona;
  String? get worldBackground => _worldBackground;
  String? get openingLine => _openingLine;
  String? get chatBackground => _chatBackground;
  bool get eroticMode => _eroticMode;
  String get mode => _mode;
  bool get showSummaryPrompt => _showSummaryPrompt;
  int? get pendingSummaryIndex => _pendingSummaryIndex;
  int get affection => (isNewFormat
          ? (_personaProvider!.currentPersona?.affection ?? _affm.affection)
          : _affm.affection)
      .round();
  String get providerType => _providerType;
  bool get affectionEnabled => _affectionEnabled;
  EmotionState? get emotionState => _affm.emotionState;
  Map<String, String> get emotionLabels => _affm.emotionLabels;
  bool get isSelfDestructMode => _affm.isSelfDestructMode;
  List<String> get quickReplies => _quickReplies;
  int? get quickReplyMessageIndex => _quickReplyMessageIndex;
  bool get isContinuing => _isContinuing;
  bool get reasoningMode => _reasoningMode;
  String get deepSeekModel => _deepSeekModel;
  bool get isDeepSeekPro => _deepSeekModel == _deepSeekProModel;
  int get remainingRecalls =>
      (_maxRecalls - _recallCount).clamp(0, _maxRecalls);
  bool get isNewFormat {
    final pp = _personaProvider;
    return pp != null && pp.personas.isNotEmpty;
  }

  String? get currentPersonaId => _personaProvider?.currentPersona?.id;

  ChatProvider(this._convProvider, [this._personaProvider]);

  RequestToken _beginRequest() {
    final token = _requestGuard.begin(
      conversationId: _currentConvId,
      personaId: currentPersonaId,
    );
    return token;
  }

  bool _isRequestCurrent(RequestToken token) {
    return _requestGuard.isCurrent(
      token,
      conversationId: _currentConvId,
      personaId: currentPersonaId,
    );
  }

  void _invalidateRequests() {
    _requestGuard.invalidate();
  }

  /// Sync current persona's affection and emotion state via AffectionManager.
  Future<void> syncPersonaState({RequestToken? requestToken}) async {
    if (!isNewFormat || _currentConvId == null) return;
    final cp = _personaProvider!.currentPersona!;
    await _affm.syncWithPersona(_currentConvId!, cp);
    if (requestToken != null && !_isRequestCurrent(requestToken)) return;
    notifyListeners();
  }

  void updateConvProvider(ConversationProvider provider) {
    _convProvider = provider;
  }

  String _normalizeDeepSeekModel(String? model) {
    final value = (model ?? '').trim().toLowerCase();
    if (value.contains('pro') || value.contains('reasoner')) {
      return _deepSeekProModel;
    }
    return _deepSeekDefaultModel;
  }

  Future<void> _rebuildDeepSeekService(String model) async {
    if (_providerType != 'deepseek') return;
    final key = await DatabaseService.getSetting('api_key');
    if (key == null || key.isEmpty) {
      notifyListeners();
      return;
    }
    final endpoint = await DatabaseService.getSetting('api_endpoint');
    _service = DeepSeekService(
      apiKey: key,
      endpoint: endpoint ?? 'https://api.deepseek.com/v1/chat/completions',
      model: model,
    );
    _affm.analyzer = EmotionAnalyzer(_service!);
    await DatabaseService.saveSetting('api_model', model);
    await AuthService.setProviderType('deepseek');
    notifyListeners();
  }

  Future<void> setApiConfig({
    required String providerType,
    required String key,
    String? endpoint,
    String? model,
  }) async {
    _providerType = providerType;
    _affectionEnabled = AuthService.supportsAffection(providerType);
    await AuthService.setProviderType(providerType);

    final defaults = AuthService.providerDefaults[providerType] ??
        AuthService.providerDefaults['custom']!;
    final chatEndpoint = endpoint ?? defaults['endpoint']!;
    final requestedModel = model ?? defaults['chat_model']!;
    final chatModel = _providerType == 'deepseek'
        ? _normalizeDeepSeekModel(requestedModel)
        : requestedModel;

    _deepSeekModel = chatModel;
    _reasoningMode = _deepSeekModel == _deepSeekProModel;

    _service = DeepSeekService(
      apiKey: key,
      endpoint: chatEndpoint,
      model: chatModel,
    );
    _affm.analyzer = EmotionAnalyzer(_service!);

    await DatabaseService.saveSetting('api_key', key);
    await DatabaseService.saveSetting('api_endpoint', chatEndpoint);
    await DatabaseService.saveSetting('api_model', chatModel);
  }

  Future<bool> loadSavedApiKey() async {
    final key = await DatabaseService.getSetting('api_key');
    if (key != null && key.isNotEmpty) {
      final endpoint = await DatabaseService.getSetting('api_endpoint');
      final model = await DatabaseService.getSetting('api_model');
      _providerType = await AuthService.getProviderType();
      _affectionEnabled = AuthService.supportsAffection(_providerType);

      final defaults = AuthService.providerDefaults[_providerType] ??
          AuthService.providerDefaults['custom']!;
      final fallbackModel = defaults['chat_model'] ?? _deepSeekDefaultModel;

      final resolvedModel = _providerType == 'deepseek'
          ? _normalizeDeepSeekModel(model ?? fallbackModel)
          : (model ?? fallbackModel);

      _deepSeekModel = resolvedModel;
      _reasoningMode = _deepSeekModel == _deepSeekProModel;

      _service = DeepSeekService(
        apiKey: key,
        endpoint: endpoint ?? 'https://api.deepseek.com/v1/chat/completions',
        model: resolvedModel,
      );
      _affm.analyzer = EmotionAnalyzer(_service!);

      if (_providerType == 'deepseek' && resolvedModel != model) {
        await DatabaseService.saveSetting('api_model', resolvedModel);
      }

      return true;
    }
    return false;
  }

  int _applyReasoningMaxTokens(int baseTokens) {
    if (!_reasoningMode) return baseTokens;
    return (baseTokens * 1.5).round();
  }

  Future<void> setReasoningMode(bool enabled) async {
    await setDeepSeekModel(enabled ? _deepSeekProModel : _deepSeekDefaultModel);
  }

  Future<void> setDeepSeekModel(String model) async {
    final normalized = _normalizeDeepSeekModel(model);
    _deepSeekModel = normalized;
    _reasoningMode = normalized == _deepSeekProModel;
    await _rebuildDeepSeekService(normalized);
  }

  /// Load saved API config for the settings dialog.
  Future<Map<String, String?>> loadApiConfig() async {
    return {
      'provider_type': await AuthService.getProviderType(),
      'key': await DatabaseService.getSetting('api_key'),
      'endpoint': await DatabaseService.getSetting('api_endpoint'),
      'model': await DatabaseService.getSetting('api_model'),
    };
  }

  Future<void> loadConversation(String convId) async {
    _invalidateRequests();
    final loadToken = _requestGuard.begin(conversationId: convId);
    _currentConvId = convId;
    _personaProvider?.prepareForConversation(convId);
    _messages = await DatabaseService.getMessages(convId);
    if (!_isRequestCurrent(loadToken)) return;
    _segments = await DatabaseService.getSegmentSummaries(convId);
    if (!_isRequestCurrent(loadToken)) return;
    await _loadRecallCount();
    if (!_isRequestCurrent(loadToken)) return;
    final conv = await DatabaseService.getConversation(convId);
    if (!_isRequestCurrent(loadToken)) return;
    _systemPrompt = conv.systemPrompt;
    _userPersona = conv.userPersona;
    _worldBackground = conv.worldBackground;
    _openingLine = conv.openingLine;
    _chatBackground = conv.chatBackground;
    _eroticMode = conv.eroticMode;
    _mode = conv.mode;
    _error = null;
    _showSummaryPrompt = false;
    _pendingSummaryIndex = null;
    _quickReplies = [];
    _quickReplyMessageIndex = null;
    _affm.roundCount =
        _messages.where((m) => m.role == 'user' && m.content.isNotEmpty).length;
    await (_personaProvider?.loadPersonas(convId) ?? Future.value());
    if (!_isRequestCurrent(loadToken)) return;

    if (isNewFormat) {
      // New format: persona-level emotion state
      await syncPersonaState(requestToken: loadToken);
      if (!_isRequestCurrent(loadToken)) return;
    } else {
      // Old format: conversation-level emotion state
      _affm.emotionState = await EmotionStateRepository.ensureForConversation(
        convId,
        initialAffection: conv.affection.toDouble(),
      );
      _affm.affection = _affm.emotionState!.affection;
      _affm.previousRawAffection = _affm.emotionState!.affection;
    } // end old-format else

    await _loadEmotionTemplateLibrary();
    if (!_isRequestCurrent(loadToken)) return;

    notifyListeners();
  }

  Future<void> _createInitialEmotionState() async {
    final conversationId = _currentConvId;
    if (conversationId == null) return;

    final personaId = isNewFormat ? currentPersonaId : null;
    final state = EmotionState.createDefault(
      conversationId,
      initialAffection: _affm.affection,
      personaId: personaId,
    );
    _affm.emotionState = state;
    if (AffectionManager.shouldUsePersonaEmotionState(
      isNewFormat: isNewFormat,
      personaId: personaId,
    )) {
      await EmotionStateRepository.insert(state);
    } else {
      await EmotionStateRepository.insert(state);
    }
  }

  void _ensureAssistantPendingBubble() {
    if (_messages.isNotEmpty &&
        _messages.last.role == 'assistant' &&
        _messages.last.content.isEmpty) {
      notifyListeners();
      return;
    }
    _messages.add(Message(
      conversationId: _currentConvId ?? '',
      role: 'assistant',
      content: '',
    ));
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _isPending = false;
    _streamingContent = '';
    notifyListeners();
  }

  void newConversation() {
    _invalidateRequests();
    _currentConvId = null;
    _personaProvider?.prepareForConversation('');
    _messages = [];
    _segments = [];
    _streamingContent = '';
    _isPending = false;
    _error = null;
    _systemPrompt = null;
    _userPersona = null;
    _worldBackground = null;
    _openingLine = null;
    _chatBackground = null;
    _eroticMode = false;
    _showSummaryPrompt = false;
    _pendingSummaryIndex = null;
    _quickReplies = [];
    _quickReplyMessageIndex = null;
    _emotionTemplateLibrary = {};
    _emotionTemplateSignature = null;
    _recallCount = 0;
    _affm.reset();
    notifyListeners();
  }

  Future<void> toggleBookmark(int messageIndex) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];

    // Rule: AI message can only be bookmarked if preceding user msg is already bookmarked
    if (msg.role == 'assistant') {
      final prevUser = messageIndex > 0 ? _messages[messageIndex - 1] : null;
      if (prevUser == null ||
          prevUser.role != 'user' ||
          !prevUser.isBookmarked) {
        // Not allowed — preceding user must be bookmarked first
        return;
      }
    }

    final newVal = !msg.isBookmarked;
    _messages[messageIndex] = msg.copyWith(isBookmarked: newVal);
    await DatabaseService.updateMessageBookmark(msg.id, newVal);
    notifyListeners();
  }

  void setInitialAffection(int value) => _affm.setInitialAffection(value);

  bool? get affectionIncreasing => _affm.affectionIncreasing;

  /// Returns true if affection just changed (consumed on read).
  bool consumeAffectionChanged() => _affm.consumeAffectionChanged();

  Future<void> setSystemPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      _systemPrompt = null;
    } else {
      _systemPrompt = trimmed;
    }
    if (_currentConvId != null) {
      final conv = await DatabaseService.getConversation(_currentConvId!);
      final updated = conv.copyWith(
        systemPrompt: _systemPrompt,
        updatedAt: DateTime.now(),
      );
      await DatabaseService.updateConversation(updated);
      await _generateEmotionTemplateLibraryIfNeeded(force: true);
    }
    notifyListeners();
  }

  Future<void> setUserPersona(String persona) async {
    final trimmed = persona.trim();
    if (trimmed.isEmpty) {
      _userPersona = null;
    } else {
      _userPersona = trimmed;
    }
    if (_currentConvId != null) {
      final conv = await DatabaseService.getConversation(_currentConvId!);
      final updated = conv.copyWith(
        userPersona: _userPersona,
        updatedAt: DateTime.now(),
      );
      await DatabaseService.updateConversation(updated);
    }
    notifyListeners();
  }

  Future<void> setWorldBackground(String background) async {
    final trimmed = background.trim();
    if (trimmed.isEmpty) {
      _worldBackground = null;
    } else {
      _worldBackground = trimmed;
    }
    if (_currentConvId != null) {
      final conv = await DatabaseService.getConversation(_currentConvId!);
      final updated = conv.copyWith(
        worldBackground: _worldBackground,
        updatedAt: DateTime.now(),
      );
      await DatabaseService.updateConversation(updated);
    }
    notifyListeners();
  }

  Future<void> setChatBackground(String? path) async {
    _chatBackground = path;
    if (_currentConvId != null) {
      final conv = await DatabaseService.getConversation(_currentConvId!);
      final updated = conv.copyWith(
        chatBackground: _chatBackground,
        updatedAt: DateTime.now(),
      );
      await DatabaseService.updateConversation(updated);
    }
    notifyListeners();
  }

  Future<void> setEroticMode(bool enabled) async {
    _eroticMode = enabled;
    if (_currentConvId != null) {
      final conv = await DatabaseService.getConversation(_currentConvId!);
      final updated = conv.copyWith(
        eroticMode: enabled,
        updatedAt: DateTime.now(),
      );
      await DatabaseService.updateConversation(updated);
    }
    notifyListeners();
  }

  Future<void> setOpeningLine(String text) async {
    final trimmed = text.trim();
    _openingLine = trimmed.isEmpty ? null : trimmed;
    if (_currentConvId != null) {
      final conv = await DatabaseService.getConversation(_currentConvId!);
      final updated = conv.copyWith(
        openingLine: _openingLine,
        updatedAt: DateTime.now(),
      );
      await DatabaseService.updateConversation(updated);
      notifyListeners();
      return;
    }
    if (_openingLine == null || _openingLine!.isEmpty) return;

    // New conversation — create one so the opening line appears in chat immediately.
    // Mirror the conversation-creation logic from sendMessage().
    final conv = await _convProvider.createConversation(
        initialAffection: _affm.affection.round(), mode: _mode);
    _currentConvId = conv.id;

    // Save system prompt if set
    if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
      await DatabaseService.updateConversation(
          conv.copyWith(systemPrompt: _systemPrompt));
    }

    // Persist pending persona
    final pp = _personaProvider;
    if (pp != null) {
      if (pp.personas.length == 1 && pp.personas.first.conversationId.isEmpty) {
        final pending = pp.personas.first;
        final persisted = AIPersona(
          id: pending.id,
          conversationId: _currentConvId!,
          name: pending.name,
          identity: pending.identity,
          personality: pending.personality,
          appearance: pending.appearance,
          notes: pending.notes,
          createdAt: pending.createdAt,
        );
        await DatabaseService.insertAIPersona(persisted);
        pp.replaceWithPersisted([persisted], _currentConvId!);
      } else {
        pp.prepareForConversation(_currentConvId!);
        await pp.loadPersonas(_currentConvId!);
        await pp.ensureDefaultPersona();
      }
    }

    // Save openingLine to conversation
    await DatabaseService.updateConversation(
        conv.copyWith(openingLine: _openingLine));

    // Create emotion state (mirrors sendMessage's new-conversation block)
    _affm.emotionState = EmotionState.createDefault(_currentConvId!,
        initialAffection: _affm.affection);
    if (isNewFormat && currentPersonaId != null) {
      _affm.emotionState = EmotionState.createDefault(
        _currentConvId!,
        initialAffection: _affm.affection,
        personaId: currentPersonaId,
      );
    }
    await EmotionStateRepository.insert(_affm.emotionState!);

    // Insert opening line as first message
    final openingMsg = Message(
      conversationId: _currentConvId!,
      role: 'assistant',
      content: _openingLine!,
    );
    _messages.add(openingMsg);
    await DatabaseService.insertMessage(openingMsg);
    notifyListeners();
  }

  Future<void> editMessage(int index, String newContent) async {
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index].copyWith(content: newContent.trim());
    _messages[index] = msg;
    await DatabaseService.updateMessage(msg);
    notifyListeners();
  }

  Future<void> _loadRecallCount() async {
    if (_currentConvId == null) {
      _recallCount = 0;
      return;
    }
    final v = await DatabaseService.getSetting('recall_count_$_currentConvId');
    _recallCount = int.tryParse(v ?? '') ?? 0;
  }

  Future<void> _bumpRecallCount() async {
    if (_currentConvId == null) return;
    _recallCount++;
    await DatabaseService.saveSetting(
        'recall_count_$_currentConvId', _recallCount.toString());
  }

  Future<void> _clearRecallCount() async {
    if (_currentConvId == null) return;
    _recallCount = 0;
    await DatabaseService.saveSetting('recall_count_$_currentConvId', '0');
  }

  Future<void> deleteMessage(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index];
    // For user messages: also delete the following AI reply (recall both)
    if (msg.role == 'user' && index + 1 < _messages.length) {
      final next = _messages[index + 1];
      if (next.role == 'assistant') {
        if (_recallCount >= _maxRecalls) return;
        await _bumpRecallCount();
        final nextMsg = _messages.removeAt(index + 1);
        await DatabaseService.deleteMessage(nextMsg.id);
      }
    }
    _messages.removeAt(index);
    await DatabaseService.deleteMessage(msg.id);
    notifyListeners();
  }

  /// Regenerate the AI response: remove this AI message, then re-stream using
  /// the existing user message (no duplicate user message insertion).
  Future<void> regenerateResponse(int aiMessageIndex) async {
    if (_isPending || _currentConvId == null) return;
    if (aiMessageIndex < 0 || aiMessageIndex >= _messages.length) return;
    if (_messages[aiMessageIndex].role != 'assistant') return;

    // Find the user message that immediately precedes this AI response
    String? userText;
    for (int i = aiMessageIndex - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') {
        userText = _messages[i].content;
        break;
      }
    }
    if (userText == null) return;

    // Remove just this AI message (not trailing messages — those are later rounds)
    final removed = _messages.removeAt(aiMessageIndex);
    await DatabaseService.deleteMessage(removed.id);

    // Stream a new AI reply (appended at end; context includes all remaining messages)
    final requestToken = _beginRequest();
    await _processAndStreamReply(userText, requestToken: requestToken);
  }

  Future<void> resetConversation() async {
    _invalidateRequests();
    if (_currentConvId == null) {
      _messages = [];
      _segments = [];
      notifyListeners();
      return;
    }
    await DatabaseService.deleteMessages(_currentConvId!);
    await DatabaseService.deleteSegmentSummaries(_currentConvId!);
    await DatabaseService.deleteAffectionLogs(_currentConvId!);
    await DatabaseService.deleteEmotionLogs(_currentConvId!);
    _messages = [];
    _segments = [];
    _isPending = false;
    await _clearRecallCount();
    _streamingContent = '';
    _error = null;
    _showSummaryPrompt = false;
    _pendingSummaryIndex = null;

    // Reset affection and emotion to initial values
    if (isNewFormat) {
      await _affm.resetForNewFormat(
          _currentConvId!, _personaProvider!.currentPersona!);
    } else {
      await _affm.resetForOldFormat(_currentConvId!);
    }
    // Update conversation affection in DB
    final conv = await DatabaseService.getConversation(_currentConvId!);
    final updated = conv.copyWith(affection: _affm.affection.round());
    await DatabaseService.updateConversation(updated);

    notifyListeners();
  }

  void clearQuickReplies() {
    _quickReplies = [];
    notifyListeners();
  }

  void dismissSummaryPrompt() {
    _showSummaryPrompt = false;
    _pendingSummaryIndex = null;
    notifyListeners();
  }

  void acceptSummaryPrompt() {
    _showSummaryPrompt = false;
    notifyListeners();
  }

  Future<void> updateSegmentSummary(int segmentIndex, String content) async {
    final idx = _segments.indexWhere((s) => s.segmentIndex == segmentIndex);
    if (idx == -1) return;
    final updated = _segments[idx].copyWith(content: content.trim());
    _segments[idx] = updated;
    await DatabaseService.updateSegmentSummary(updated);
    _pendingSummaryIndex = null;
    notifyListeners();
  }

  SegmentSummary? getSegment(int segmentIndex) {
    final idx = _segments.indexWhere((s) => s.segmentIndex == segmentIndex);
    return idx == -1 ? null : _segments[idx];
  }

  /// Stream an assistant reply from the API, save to DB, and update in-memory display.
  /// Returns the raw full response content, or null on error (error already set on provider).
  Future<StreamedReply?> _streamAssistantReply({
    required List<Map<String, dynamic>> contextMsgs,
    required double temperature,
    int? maxTokens,
    int? maxCharsForDisplay,
    required RequestToken requestToken,
  }) async {
    if (!_isRequestCurrent(requestToken)) return null;
    final hasPendingBubble = _messages.isNotEmpty &&
        _messages.last.role == 'assistant' &&
        _messages.last.content.isEmpty;
    final assistantMsg = hasPendingBubble
        ? _messages.last
        : Message(
            conversationId: _currentConvId!,
            role: 'assistant',
            content: '',
          );
    if (!hasPendingBubble) {
      _messages.add(assistantMsg);
      notifyListeners();
    }

    try {
      int? totalTokensUsed;
      final fullContent = await _service!.streamChatRaw(
        contextMessages: contextMsgs,
        temperature: temperature,
        maxTokens: maxTokens,
        onUsage: (usage) {
          final t = usage.totalTokens;
          if (t != null && t > 0) {
            totalTokensUsed = t;
          }
        },
        onToken: (token) {
          if (!_isRequestCurrent(requestToken)) return;
          _streamingContent += token;
          var display =
              StructuredReplyParser.visibleText(_streamingContent);
          if (maxCharsForDisplay != null && maxCharsForDisplay > 0) {
            display = _truncateByChars(display, maxCharsForDisplay);
          }
          final index = _messages.indexWhere((message) => message.id == assistantMsg.id);
          if (index == -1) return;
          _messages[index] = assistantMsg.copyWith(content: display);
          notifyListeners();
        },
        onDone: () => _streamingContent = '',
      );

      if (!_isRequestCurrent(requestToken)) {
        return null;
      }
      final parsed = StructuredReplyParser.parseAny(fullContent);
      final fallbackTotal =
          DeepSeekService.estimateTotalTokens(contextMsgs, fullContent);
      final savedMsg = assistantMsg.copyWith(
        content: parsed.reply,
        totalTokens: totalTokensUsed ?? fallbackTotal,
      );
      final index = _messages.indexWhere((message) => message.id == assistantMsg.id);
      if (index == -1) return null;
      _messages[index] = savedMsg;
      await DatabaseService.insertMessage(savedMsg);
      return StreamedReply(raw: fullContent, parsed: parsed);
    } catch (e) {
      if (!_isRequestCurrent(requestToken)) return null;
      _error = '请求失败: $e';
      final index = _messages.indexWhere((message) => message.id == assistantMsg.id);
      if (index != -1 && _messages[index].content.isEmpty) {
        _messages.removeAt(index);
      }
      return null;
    }
  }

  /// Shared AI reply pipeline: build context, apply output limits, stream,
  /// post-process (delta / affection / quick-reply / archive / emotion).
  /// Does NOT insert a user message — the caller must ensure _messages
  /// already ends with the triggering user message.
  Future<void> _processAndStreamReply(
    String userText, {
    required RequestToken requestToken,
  }) async {
    if (!_isRequestCurrent(requestToken)) return;
    _error = null;

    if (_shouldRefuseNonEroticRequest(userText)) {
      await _appendImmediateNonEroticRefusal(requestToken: requestToken);
      return;
    }

    final conv = await DatabaseService.getConversation(_currentConvId!);
    if (!_isRequestCurrent(requestToken)) return;
    final safeMode = await AuthService.getAdminSafeMode();
    final doAffectionJudge =
        _affectionEnabled && !safeMode && _affm.shouldJudgeAffection;
    final roleplayRule = await AuthService.getRoleplayRule();
    final immersiveRoleplayPrompt =
        await AuthService.getImmersiveRoleplayPrompt();
    final userMessageCount =
        _messages.where((message) => message.role == 'user').length;
    final kbResults = await KnowledgeBase.search(userText, limit: 3);
    final quickReplyTone = await AuthService.getQuickReplyTone();
    await _generateEmotionTemplateLibraryIfNeeded();
    final selfEmotionTemplate = _buildSelfEmotionTemplateFromLibrary();
    final contextMsgs = await ContextBuilder.build(
      conversationId: _currentConvId!,
      systemPrompt: _systemPrompt,
      conversationPrompt: conv.systemPrompt,
      userPersona: _userPersona ?? conv.userPersona,
      worldBackground: _worldBackground ?? conv.worldBackground,
      emotionState: _affm.emotionState,
      affectionEnabled: _affectionEnabled,
      mode: _mode,
      roleplayRule: roleplayRule,
      immersiveRoleplayPrompt: immersiveRoleplayPrompt,
      eroticMode: _eroticMode,
      quickReplyTone: quickReplyTone,
      selfEmotionTemplate: selfEmotionTemplate,
      messages: _messages,
      segments: _segments,
      kbResults: kbResults,
      injectStructuredReply: true,
      includeAffectionDelta: doAffectionJudge,
      includeQuickReplies: _affectionEnabled,
      injectRoleplayRule:
          ContextBuilder.shouldInjectRoleplayRule(userMessageCount),
    );
    if (!_isRequestCurrent(requestToken)) return;

    // Output length limits
    final minChars = await AuthService.getMinOutputChars();
    final maxChars = await AuthService.getMaxOutputChars();
    int? maxTokens;
    if (maxChars > 0) {
      maxTokens = _applyReasoningMaxTokens(
        DeepSeekService.charsToMaxTokens(maxChars),
      );
    }
    ChatRequestService.addLengthDirectives(
      contextMsgs,
      minChars: minChars,
      maxChars: maxChars,
    );

    final temp = ChatRequestService.temperature(
      affectionEnabled: _affectionEnabled,
      affection: _affm.affection,
    );
    final streamed = await _streamAssistantReply(
      contextMsgs: contextMsgs,
      temperature: temp,
      maxTokens: maxTokens,
      maxCharsForDisplay: maxChars > 0 ? maxChars : null,
      requestToken: requestToken,
    );

    double? inlineDelta;
    String? inlineReason;

    if (streamed != null && _isRequestCurrent(requestToken)) {
      var cleanContent = streamed.parsed.reply;
      inlineDelta = doAffectionJudge ? streamed.parsed.affectionDelta : null;
      inlineReason =
          doAffectionJudge ? streamed.parsed.affectionReason : null;

      if (maxChars > 0) {
        final trimmed = _truncateByChars(cleanContent, maxChars);
        if (trimmed != cleanContent) {
          cleanContent = trimmed;
          _messages[_messages.length - 1] =
              _messages[_messages.length - 1].copyWith(content: cleanContent);
          await DatabaseService.insertMessage(_messages[_messages.length - 1]);
        }
      }

      cleanContent = await _forceMinCharsForLastAssistant(
        baseContextMsgs: contextMsgs,
        currentContent: cleanContent,
        minChars: minChars,
        maxChars: maxChars,
        temperature: temp,
        requestToken: requestToken,
      );

      var finalQuickReplies = streamed.parsed.quickReplies;

      // Enforce minimum length on visible正文.
      if (minChars > 0 && _runeLength(cleanContent) < minChars) {
        cleanContent = await _forceMinCharsForLastAssistant(
          baseContextMsgs: contextMsgs,
          currentContent: cleanContent,
          minChars: minChars,
          maxChars: maxChars,
          temperature: temp,
          suppressQuickReplies: true,
          requestToken: requestToken,
        );
      }

      final enforced = _enforceNonEroticOutput(
        content: cleanContent,
        quickReplies: finalQuickReplies,
      );
      cleanContent = enforced.content;
      finalQuickReplies = enforced.quickReplies;

      if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
        _messages[_messages.length - 1] =
            _messages[_messages.length - 1].copyWith(content: cleanContent);
        await DatabaseService.insertMessage(_messages[_messages.length - 1]);
      }

      if (inlineDelta != null && !safeMode) {
        await _affm.applyDelta(
          delta: inlineDelta,
          reason: inlineReason ?? '',
          convId: _currentConvId!,
          personaId: currentPersonaId,
          userMessage: userText,
          aiMessage: cleanContent,
        );
        if (isNewFormat) {
          _personaProvider!.currentPersona!.affection = _affm.affection;
        }
      }

      final updatedConv = conv.copyWith(
          updatedAt: DateTime.now(), affection: _affm.affection.round());
      await DatabaseService.updateConversation(updatedConv);

      if (finalQuickReplies.isNotEmpty) {
        _messages[_messages.length - 1] = _messages[_messages.length - 1]
            .copyWith(content: cleanContent, quickReplies: finalQuickReplies);
        await DatabaseService.insertMessage(_messages[_messages.length - 1]);
        _quickReplies = finalQuickReplies;
        _quickReplyMessageIndex = _messages.length - 1;
      } else {
        _messages[_messages.length - 1] =
            _messages[_messages.length - 1].copyWith(content: cleanContent);
        await DatabaseService.insertMessage(_messages[_messages.length - 1]);
        _quickReplies = [];
        _quickReplyMessageIndex = null;
      }
    }

    if (!_isRequestCurrent(requestToken)) return;
    _isPending = false;
    _streamingContent = '';

    await _maybeArchiveSegment();

    notifyListeners();

    if (streamed != null) {
      if (inlineDelta != null) {
        _affm.previousRawAffection = _affm.affection;
      }
      if (_affectionEnabled &&
          _affm.analyzer != null &&
          _affm.emotionState != null &&
          !safeMode) {
        Future.delayed(
          const Duration(milliseconds: 300),
          () => _doEmotionAnalysis(userText, requestToken: requestToken),
        );
      }
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isPending) return;
    if (_service == null) {
      _error = '请先设置 API Key';
      notifyListeners();
      return;
    }
    // Require persona before chatting
    if (_systemPrompt == null || _systemPrompt!.trim().isEmpty) {
      _error = '请先点击右上角 ✨ 按钮设定角色规则';
      notifyListeners();
      return;
    }

    _error = null;
    final requestToken = _beginRequest();

    if (_currentConvId == null) {
      final conv = await _convProvider.createConversation(
          initialAffection: _affm.affection.round(), mode: _mode);
      _currentConvId = conv.id;
      _recallCount = 0; // fresh conversation — no recalls used yet
      if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
        final updated = conv.copyWith(systemPrompt: _systemPrompt);
        await DatabaseService.updateConversation(updated);
      }
      // Initialize / persist personas for new conversation
      final pp = _personaProvider;
      if (pp != null) {
        if (pp.personas.length == 1 &&
            pp.personas.first.conversationId.isEmpty) {
          // Persist the pending persona with the real conversation ID
          final pending = pp.personas.first;
          final persisted = AIPersona(
            id: pending.id,
            conversationId: _currentConvId!,
            name: pending.name,
            identity: pending.identity,
            personality: pending.personality,
            appearance: pending.appearance,
            notes: pending.notes,
            createdAt: pending.createdAt,
          );
          await DatabaseService.insertAIPersona(persisted);
          pp.replaceWithPersisted([persisted], _currentConvId!);
        } else {
          pp.prepareForConversation(_currentConvId!);
          await pp.loadPersonas(_currentConvId!);
          await pp.ensureDefaultPersona();
        }
      }
      await _createInitialEmotionState();
      if (!_isRequestCurrent(requestToken)) return;
      await _generateEmotionTemplateLibraryIfNeeded(force: true);
      if (!_isRequestCurrent(requestToken)) return;

      // Save openingLine to conversation
      if (_openingLine != null && _openingLine!.isNotEmpty) {
        final convWithLine = conv.copyWith(openingLine: _openingLine);
        await DatabaseService.updateConversation(convWithLine);
        // Inject opening line as first assistant message
        final openingMsg = Message(
          conversationId: _currentConvId!,
          role: 'assistant',
          content: _openingLine!,
        );
        _messages.add(openingMsg);
        await DatabaseService.insertMessage(openingMsg);
        _openingLine = null; // consumed
      }

      if (_eroticMode) {
        final latestConv =
            await DatabaseService.getConversation(_currentConvId!);
        if (!latestConv.eroticMode) {
          await DatabaseService.updateConversation(
              latestConv.copyWith(eroticMode: true));
        }
      }
    }

    final userMsg = Message(
      conversationId: _currentConvId!,
      role: 'user',
      content: text.trim(),
    );
    _messages.add(userMsg);
    await DatabaseService.insertMessage(userMsg);
    if (!_isRequestCurrent(requestToken)) return;
    _isPending = true;
    _streamingContent = '';
    _ensureAssistantPendingBubble();

    if (_shouldRefuseNonEroticRequest(text.trim())) {
      _affm.roundCount++;
      await _appendImmediateNonEroticRefusal(requestToken: requestToken);
      return;
    }

    final conv = await DatabaseService.getConversation(_currentConvId!);
    if (conv.title == '新对话') {
      final t = text.trim();
      final title = t.length > 20 ? '${t.substring(0, 20)}...' : t;
      await _convProvider.updateTitle(_currentConvId!, title);
    }

    // Increment round count, then delegate to shared reply pipeline
    _affm.roundCount++;
    await _processAndStreamReply(text.trim(), requestToken: requestToken);
  }

  static String _truncateByChars(String text, int maxChars) {
    if (maxChars <= 0) return text;
    final rs = text.runes.toList();
    if (rs.length <= maxChars) return text;
    return String.fromCharCodes(rs.take(maxChars));
  }

  String? _emotionTemplateStorageKey() {
    if (_currentConvId == null) return null;
    return 'emotion_template_${_currentConvId}_${currentPersonaId ?? 'default'}';
  }

  String _currentEmotionTemplateSignature() {
    final labels = _affm.emotionLabels;
    final persona = (_systemPrompt ?? '').trim();
    return [
      currentPersonaId ?? 'default',
      persona,
      _eroticMode ? 'erotic' : 'safe',
      labels['towards_user'] ?? '',
      labels['self_state'] ?? '',
    ].join('||');
  }

  List<String> _collectAllEmotionLabels() {
    final set = <String>{};
    const buckets = [0.0, 12.5, 25.0, 37.5, 50.0];
    const affections = [0.0, 25.0, 50.0, 75.0, 100.0];

    for (final aff in affections) {
      for (final lo in buckets) {
        for (final ao in buckets) {
          final state = EmotionState(
            id: 'tmp',
            conversationId: _currentConvId ?? 'tmp',
            affection: aff,
            currentLibidoOther: lo,
            currentAggressionOther: ao,
            currentLibidoSelf: 25.0,
            currentAggressionSelf: 25.0,
          );
          final labels = EmotionTables.getEmotionDescription(state);
          final toward = labels['towards_user'];
          if (toward != null && toward.trim().isNotEmpty) {
            set.add(toward.trim());
          }
        }
      }
    }

    for (final ls in buckets) {
      for (final asv in buckets) {
        final state = EmotionState(
          id: 'tmp',
          conversationId: _currentConvId ?? 'tmp',
          affection: 50.0,
          currentLibidoOther: 25.0,
          currentAggressionOther: 25.0,
          currentLibidoSelf: ls,
          currentAggressionSelf: asv,
        );
        final labels = EmotionTables.getEmotionDescription(state);
        final self = labels['self_state'];
        if (self != null && self.trim().isNotEmpty) set.add(self.trim());
      }
    }

    final list = set.toList()..sort();
    return list;
  }

  String _fallbackTemplate(String emotion) {
    return _truncateByChars('我带着$emotion，自然回应你', 20);
  }

  String _normalizeShortTemplate(String text) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _truncateByChars(clean, 20);
  }

  Map<String, dynamic>? _decodeJsonObject(String raw) {
    try {
      final direct = jsonDecode(raw);
      if (direct is Map<String, dynamic>) return direct;
    } catch (_) {}

    final s = raw.indexOf('{');
    final e = raw.lastIndexOf('}');
    if (s >= 0 && e > s) {
      final slice = raw.substring(s, e + 1);
      try {
        final v = jsonDecode(slice);
        if (v is Map<String, dynamic>) return v;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _loadEmotionTemplateLibrary() async {
    final key = _emotionTemplateStorageKey();
    if (key == null) return;
    final raw = await DatabaseService.getSetting(key);
    if (raw == null || raw.trim().isEmpty) return;
    final root = _decodeJsonObject(raw);
    if (root == null) return;

    final sig = root['signature'] as String?;
    final lib = root['templates'];
    if (lib is! Map) return;

    final parsed = <String, String>{};
    for (final entry in lib.entries) {
      final emotion = entry.key.toString();
      final v = entry.value;
      if (v is String && v.trim().isNotEmpty) {
        parsed[emotion] = _normalizeShortTemplate(v);
      }
    }

    _emotionTemplateLibrary = parsed;
    _emotionTemplateSignature = sig;
  }

  Future<void> _saveEmotionTemplateLibrary() async {
    final key = _emotionTemplateStorageKey();
    if (key == null) return;
    await DatabaseService.saveSetting(
      key,
      jsonEncode({
        'signature': _emotionTemplateSignature,
        'templates': _emotionTemplateLibrary,
      }),
    );
  }

  Future<void> ensureEmotionTemplateLibraryReady() async {
    if (_emotionTemplateLibrary.isEmpty) {
      await _generateEmotionTemplateLibraryIfNeeded();
    }
  }

  String? getCurrentTowardsTemplate() {
    final label = _affm.emotionLabels['towards_user']?.trim();
    if (label == null || label.isEmpty) return null;
    return _emotionTemplateLibrary[label];
  }

  String? getCurrentSelfTemplate() {
    final label = _affm.emotionLabels['self_state']?.trim();
    if (label == null || label.isEmpty) return null;
    return _emotionTemplateLibrary[label];
  }

  Future<void> updateCurrentEmotionTemplates({
    required String towardsTemplate,
    required String selfTemplate,
  }) async {
    await ensureEmotionTemplateLibraryReady();

    final towardLabel = _affm.emotionLabels['towards_user']?.trim();
    final selfLabel = _affm.emotionLabels['self_state']?.trim();
    if (towardLabel != null && towardLabel.isNotEmpty) {
      _emotionTemplateLibrary[towardLabel] =
          _normalizeShortTemplate(towardsTemplate);
    }
    if (selfLabel != null && selfLabel.isNotEmpty) {
      _emotionTemplateLibrary[selfLabel] =
          _normalizeShortTemplate(selfTemplate);
    }

    await _saveEmotionTemplateLibrary();
    notifyListeners();
  }

  Future<void> _generateEmotionTemplateLibraryIfNeeded(
      {bool force = false}) async {
    if (_service == null || !_affectionEnabled) return;
    if (_currentConvId == null) return;
    if (_systemPrompt == null || _systemPrompt!.trim().isEmpty) return;

    final signature = _currentEmotionTemplateSignature();
    if (!force &&
        _emotionTemplateLibrary.isNotEmpty &&
        _emotionTemplateSignature == signature) {
      return;
    }

    if (_emotionTemplateLibrary.isEmpty || force) {
      await _loadEmotionTemplateLibrary();
      if (!force &&
          _emotionTemplateLibrary.isNotEmpty &&
          _emotionTemplateSignature == signature) {
        return;
      }
    }

    final emotions = _collectAllEmotionLabels();
    if (emotions.isEmpty) return;

    final safeRule =
        _eroticMode ? '可有成人向亲密表达，但必须保持人设，不要跳出角色。' : '不得出现色情露骨、违法犯罪、涉政敏感表达。';

    final prompt = '''
根据下面的人设，为每个情绪标签分别生成一条“情绪短模板”。

【人设】
${_systemPrompt!.trim()}

【硬规则】$safeRule

【情绪标签列表】
${emotions.join('、')}

输出要求：
1. 仅输出 JSON 对象。
2. 最外层 key 是情绪标签，value 是模板字符串。
3. 每条模板必须 <=20字，第一人称，直接可用于回复时的情绪基调。
4. 禁止额外解释、禁止Markdown代码块。

JSON 示例：
{"喜欢":"我有点心动，愿多聊"}
''';

    final generated = <String, String>{};
    try {
      final raw = await _service!.chatRaw(
        prompt,
        '你是模板生成器，只输出合法JSON对象。',
        maxTokens: 2200,
      );
      final root = _decodeJsonObject(raw);
      if (root != null) {
        for (final emotion in emotions) {
          final v = root[emotion];
          if (v is String && v.trim().isNotEmpty) {
            generated[emotion] = _normalizeShortTemplate(v);
          } else {
            generated[emotion] = _fallbackTemplate(emotion);
          }
        }
      }
    } catch (_) {
      // Ignore and fill fallbacks below.
    }

    if (generated.isEmpty) {
      for (final emotion in emotions) {
        generated[emotion] = _fallbackTemplate(emotion);
      }
    }

    _emotionTemplateLibrary = generated;
    _emotionTemplateSignature = signature;
    await _saveEmotionTemplateLibrary();
  }

  String? _buildSelfEmotionTemplateFromLibrary() {
    if (_emotionTemplateLibrary.isEmpty) return null;
    final labels = _affm.emotionLabels;
    final toward = labels['towards_user']?.trim();
    final self = labels['self_state']?.trim();

    String? towardTpl;
    String? selfTpl;
    if (toward != null && toward.isNotEmpty) {
      towardTpl = _emotionTemplateLibrary[toward];
    }
    if (self != null && self.isNotEmpty) {
      selfTpl = _emotionTemplateLibrary[self];
    }

    final parts = <String>[];
    if (towardTpl != null && towardTpl.isNotEmpty) {
      parts.add('对用户：$towardTpl');
    }
    if (selfTpl != null && selfTpl.isNotEmpty) {
      parts.add('自我：$selfTpl');
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  static int _runeLength(String text) => text.runes.length;

  bool _containsBlockedContentInNonErotic(String text) {
    if (_eroticMode) return false;
    return ContentSafetyService.containsBlockedContent(text);
  }

  bool _shouldRefuseNonEroticRequest(String userText) {
    if (_eroticMode) return false;
    final t = userText.trim();
    if (t.isEmpty) return false;
    return ContentSafetyService.shouldRefuseUserRequest(t);
  }

  String _nonEroticRefusalMessage() {
    return '我不能提供色情、违法或涉政敏感内容。'
        '我们可以换个方向：比如聊日常心情、关系推进或正常剧情发展。';
  }

  Future<void> _appendImmediateNonEroticRefusal({
    RequestToken? requestToken,
  }) async {
    if (_currentConvId == null) return;
    if (requestToken != null && !_isRequestCurrent(requestToken)) return;

    final assistantMsg = Message(
      conversationId: _currentConvId!,
      role: 'assistant',
      content: _nonEroticRefusalMessage(),
    );
    if (_messages.isNotEmpty &&
        _messages.last.role == 'assistant' &&
        _messages.last.content.isEmpty) {
      _messages[_messages.length - 1] = assistantMsg;
      await DatabaseService.insertMessage(assistantMsg);
    } else {
      _messages.add(assistantMsg);
      await DatabaseService.insertMessage(assistantMsg);
    }

    final conv = await DatabaseService.getConversation(_currentConvId!);
    if (requestToken != null && !_isRequestCurrent(requestToken)) return;
    await DatabaseService.updateConversation(
        conv.copyWith(updatedAt: DateTime.now()));

    _quickReplies = [];
    _quickReplyMessageIndex = null;
    _isPending = false;
    _streamingContent = '';
    notifyListeners();
  }

  ({String content, List<String> quickReplies}) _enforceNonEroticOutput(
      {required String content, required List<String> quickReplies}) {
    if (_eroticMode) return (content: content, quickReplies: quickReplies);

    if (_containsBlockedContentInNonErotic(content)) {
      return (content: _nonEroticRefusalMessage(), quickReplies: const []);
    }

    if (quickReplies.isEmpty) {
      return (content: content, quickReplies: quickReplies);
    }

    final safeReplies = quickReplies
        .where((q) => !_containsBlockedContentInNonErotic(q))
        .toList();
    if (safeReplies.length < 2) {
      return (content: content, quickReplies: const []);
    }
    return (content: content, quickReplies: safeReplies.take(2).toList());
  }

  Future<String> _forceMinCharsForLastAssistant({
    required List<Map<String, dynamic>> baseContextMsgs,
    required String currentContent,
    required int minChars,
    required int maxChars,
    required double temperature,
    required RequestToken requestToken,
    bool suppressQuickReplies = false,
  }) async {
    if (minChars <= 0 ||
        _service == null ||
        !_isRequestCurrent(requestToken)) {
      return currentContent;
    }
    if (_messages.isEmpty || _messages.last.role != 'assistant') {
      return currentContent;
    }

    var content = currentContent;
    var tries = 0;
    const maxRetries = 2;

    while (_runeLength(content) < minChars && tries < maxRetries) {
      final deficit = minChars - _runeLength(content);
      final remainingCap =
          maxChars > 0 ? (maxChars - _runeLength(content)) : 999999;
      if (remainingCap <= 0) break;

      final askChars = (deficit + 48).clamp(16, remainingCap);
      final fillContext = <Map<String, dynamic>>[
        ...baseContextMsgs,
        {'role': 'assistant', 'content': content},
        {
          'role': 'system',
          'content':
                  '你上一条回复未达到最少$minChars个汉字。请只续写正文，不要重复前文，不要加解释、编号、标签，补充约$askChars个汉字。'
                  '${suppressQuickReplies ? ' 本次补写不生成快捷回复，quick_replies 必须为空数组。' : ''}'
        },
      ];

      int? usageTotal;
      var rawFragment = '';
      final baseContent = content;
      final appended = await _service!.streamChatRaw(
        contextMessages: fillContext,
        temperature: temperature,
        maxTokens: DeepSeekService.charsToMaxTokens(askChars),
        onUsage: (usage) {
          final t = usage.totalTokens;
          if (t != null && t > 0) usageTotal = t;
        },
        onToken: (token) {
          if (!_isRequestCurrent(requestToken)) return;
          rawFragment += token;
          final appendedVisible =
              StructuredReplyParser.visibleText(rawFragment);
          content = baseContent + appendedVisible;
          if (maxChars > 0) {
            content = _truncateByChars(content, maxChars);
          }
          final idx = _messages.length - 1;
          _messages[idx] = _messages[idx].copyWith(content: content);
          notifyListeners();
        },
        onDone: () => _streamingContent = '',
      );

      if (!_isRequestCurrent(requestToken) || appended.trim().isEmpty) break;
      final appendedVisible =
          StructuredReplyParser.parseAny(appended).reply;
      if (appendedVisible.trim().isEmpty) break;
      final estimatedUsage =
          DeepSeekService.estimateTotalTokens(fillContext, appended);
      final deltaTokens = usageTotal ?? estimatedUsage;

      content = _truncateByChars(
        baseContent + appendedVisible,
        maxChars,
      );
      final idx = _messages.length - 1;
      final prevTotal = _messages[idx].totalTokens ?? 0;
      _messages[idx] =
          _messages[idx].copyWith(totalTokens: prevTotal + deltaTokens);
      await DatabaseService.insertMessage(_messages[idx]);

      tries++;
    }

    return content;
  }

  /// Unified emotion analysis via unconscious LLM.
  /// Delegates to AffectionManager for all emotion/affection state updates.
  Future<void> _doEmotionAnalysis(
    String userMessage, {
    required RequestToken requestToken,
  }) async {
    if (!_isRequestCurrent(requestToken) ||
        _currentConvId == null ||
        !_affectionEnabled) {
      return;
    }

    final allMsgs = _messages.where((m) => m.content.isNotEmpty).toList();
    final aiMsgs = allMsgs.where((m) => m.role == 'assistant').toList();
    final lastAiMsg = aiMsgs.isNotEmpty ? aiMsgs.last.content : '';
    final history = allMsgs.map((m) => '${m.role}: ${m.content}').join('\n');

    final sensitivity = await AuthService.getEmotionSensitivity();
    final boostedSensitivity = (sensitivity * 2.3).clamp(0.5, 3.0);

    await _affm.analyzeEmotion(
      userMessage: userMessage,
      lastAiMessage: lastAiMsg,
      history: history,
      convId: _currentConvId!,
      personaId: currentPersonaId,
      sensitivity: boostedSensitivity,
      isNewFormat: isNewFormat,
      persona: isNewFormat ? _personaProvider?.currentPersona : null,
      isRequestCurrent: () => _isRequestCurrent(requestToken),
    );

    if (!_isRequestCurrent(requestToken)) return;
    notifyListeners();
  }

  /// Mark a quick reply as consumed for this round and return the text.
  /// The caller should insert the returned text into the input field.
  String? consumeQuickReply(int index) {
    if (index < 0 || index >= _quickReplies.length) return null;
    final text = _quickReplies[index];
    _quickReplies = [];
    _quickReplyMessageIndex = null;
    notifyListeners();
    return text;
  }

  /// Let AI continue without user input (no visible user message).
  Future<void> sendContinueCommand() async {
    if (_isPending ||
        _isContinuing ||
        _service == null ||
        _currentConvId == null) return;
    final requestToken = _beginRequest();
    _isContinuing = true;
    _isPending = true;
    _streamingContent = '';
    _ensureAssistantPendingBubble();

    // Build context with hidden structured output and no metadata for continue.
    final conv = await DatabaseService.getConversation(_currentConvId!);
    final immersiveRoleplayPrompt =
        await AuthService.getImmersiveRoleplayPrompt();
    if (!_isRequestCurrent(requestToken)) return;
    final lastAi = _messages
        .where((m) => m.role == 'assistant' && m.content.isNotEmpty)
        .lastOrNull;
    final kbResults = lastAi != null
        ? await KnowledgeBase.search(lastAi.content, limit: 3)
        : <({String title, String content})>[];
    await _generateEmotionTemplateLibraryIfNeeded();
    final selfEmotionTemplate = _buildSelfEmotionTemplateFromLibrary();
    final contextMsgs = await ContextBuilder.build(
      conversationId: _currentConvId!,
      systemPrompt: _systemPrompt,
      conversationPrompt: conv.systemPrompt,
      userPersona: _userPersona ?? conv.userPersona,
      worldBackground: _worldBackground ?? conv.worldBackground,
      emotionState: _affm.emotionState,
      affectionEnabled: _affectionEnabled,
      mode: _mode,
      eroticMode: _eroticMode,
      selfEmotionTemplate: selfEmotionTemplate,
      messages: _messages,
      segments: _segments,
      kbResults: kbResults,
      immersiveRoleplayPrompt: immersiveRoleplayPrompt,
      injectStructuredReply: true,
      includeAffectionDelta: false,
      includeQuickReplies: false,
      injectContinue: true,
    );
    if (!_isRequestCurrent(requestToken)) return;

    // Output length limits
    final minCharsCont = await AuthService.getMinOutputChars();
    final maxCharsCont = await AuthService.getMaxOutputChars();
    int? maxTokensCont;
    if (maxCharsCont > 0) {
      maxTokensCont = _applyReasoningMaxTokens(
        DeepSeekService.charsToMaxTokens(maxCharsCont),
      );
    }
    ChatRequestService.addLengthDirectives(
      contextMsgs,
      minChars: minCharsCont,
      maxChars: maxCharsCont,
    );

    final temp = ChatRequestService.temperature(
      affectionEnabled: _affectionEnabled,
      affection: _affm.affection.round().toDouble(),
    );
    final streamed = await _streamAssistantReply(
      contextMsgs: contextMsgs,
      temperature: temp,
      maxTokens: maxTokensCont,
      maxCharsForDisplay: maxCharsCont > 0 ? maxCharsCont : null,
      requestToken: requestToken,
    );

    if (streamed != null && _isRequestCurrent(requestToken)) {
      if (maxCharsCont > 0) {
        final trimmed = _truncateByChars(streamed.visible, maxCharsCont);
        if (trimmed != streamed.visible &&
            _messages.isNotEmpty &&
            _messages.last.role == 'assistant') {
          _messages[_messages.length - 1] =
              _messages[_messages.length - 1].copyWith(content: trimmed);
          await DatabaseService.insertMessage(_messages[_messages.length - 1]);
        }
      }

      if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
        await _forceMinCharsForLastAssistant(
          baseContextMsgs: contextMsgs,
          currentContent: _messages.last.content,
          minChars: minCharsCont,
          maxChars: maxCharsCont,
          temperature: temp,
          requestToken: requestToken,
        );

        if (!_eroticMode) {
          final latest = _messages.last.content;
          if (_containsBlockedContentInNonErotic(latest)) {
            _messages[_messages.length - 1] = _messages[_messages.length - 1]
                .copyWith(content: _nonEroticRefusalMessage());
            await DatabaseService.insertMessage(
                _messages[_messages.length - 1]);
          }
        }
      }

      final updatedConv = conv.copyWith(updatedAt: DateTime.now());
      await DatabaseService.updateConversation(updatedConv);
    }

    if (!_isRequestCurrent(requestToken)) return;
    _isPending = false;
    _streamingContent = '';
    _isContinuing = false;
    await _maybeArchiveSegment();
    notifyListeners();
  }

  Future<void> _maybeArchiveSegment() async {
    if (_currentConvId == null) return;

    final unarchived = ChatMemoryService.selectArchive(
      _messages,
      count: _messages.length,
    );

    if (unarchived.length < triggerArchiveAt) return;

    final toArchive = unarchived.take(archiveCount).toList();
    final toArchiveIds = toArchive.map((m) => m.id).toList();
    final segmentIndex =
        _segments.isEmpty ? 0 : _segments.last.segmentIndex + 1;

    final summary = SegmentSummary(
      conversationId: _currentConvId!,
      segmentIndex: segmentIndex,
    );
    await DatabaseService.insertSegmentSummary(summary);
    await DatabaseService.updateMessageArchiveStatus(
        toArchiveIds, segmentIndex);

    for (int i = 0; i < _messages.length; i++) {
      if (toArchiveIds.contains(_messages[i].id)) {
        _messages[i] = _messages[i].copyWith(segmentIndex: segmentIndex);
      }
    }

    _segments.add(summary);

    // Summarization: only in summary mode; skip entirely in bookmark mode
    if (_mode == 'bookmark') {
      _showSummaryPrompt = false;
      _pendingSummaryIndex = null;
      return;
    }

    // Always generate AI summary with persona (diary-style), regardless of auto/manual.
    if (_service != null) {
      try {
        final archiveText = ChatMemoryService.formatArchiveText(toArchive);

        // Build in-character diary-style summary prompt using persona
        final persona =
            (_systemPrompt != null && _systemPrompt!.trim().isNotEmpty)
                ? _systemPrompt!.trim()
                : null;
        final systemPrompt = persona != null
            ? '$persona\n\n现在，你正在写日记，以第一人称「我」的口吻回顾刚才发生的事。你必须完全保持设定中的性格、语气和说话风格。日记内容要像角色本人写的，不要像第三人称总结。写得简短精炼，只记录最关键的事件和情绪变化，不要流水账。'
            : '你是总结助手。请用第一人称「我」的口吻回顾以下对话，保持角色的性格和语气。写得简短精炼，只抓重点，不要展开。';
        final userPrompt = persona != null
            ? '用你的口吻，以第一人称写一段日记，回顾以下对话中发生的事。要求：写短一点，写准一点，只挑最重要的写，不要逐句复述。\n\n$archiveText'
            : '请用第一人称总结以下对话要点，写短写准，只抓关键信息：\n\n$archiveText';

        final result =
            await _service!.chatRaw(userPrompt, systemPrompt, maxTokens: 800);
        final trimmed = result.trim();
        if (trimmed.isNotEmpty) {
          final updated = summary.copyWith(content: trimmed);
          await DatabaseService.updateSegmentSummary(updated);
          final idx =
              _segments.indexWhere((s) => s.segmentIndex == segmentIndex);
          if (idx != -1) _segments[idx] = updated;
        }
      } catch (e) {
        debugPrint('[Summary] AI 总结生成失败: $e');
      }
    }

    final autoSummary = await AuthService.getAutoSummaryEnabled();
    if (autoSummary) {
      // Auto mode: save silently, no banner
      _showSummaryPrompt = false;
      _pendingSummaryIndex = null;
    } else {
      // Manual mode: show banner with pre-filled AI content ready for editing
      _showSummaryPrompt = true;
      _pendingSummaryIndex = segmentIndex;
    }
  }

  int? lastMessageIndexOfSegment(int segmentIndex) {
    int? lastIdx;
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].segmentIndex == segmentIndex) lastIdx = i;
    }
    return lastIdx;
  }
}
