import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../models/segment_summary.dart';
import '../models/affection_log.dart';
import '../models/emotion_state.dart';
import '../services/deepseek_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/emotion_service.dart';
import '../services/context_builder.dart';
import '../services/json_utils.dart';
import 'conversation_provider.dart';

class ChatProvider extends ChangeNotifier {
  // Memory thresholds: 20 rounds (40 msgs) max, archive 5 rounds (10 msgs) at a time
  static const maxActiveMessages = 40;
  static const triggerArchiveAt = 40;
  static const archiveCount = 10;

  ConversationProvider _convProvider;
  DeepSeekService? _service; // chat model
  String _providerType = 'deepseek';
  bool _affectionEnabled = true;
  String? _currentConvId;
  String? _systemPrompt;
  String? _userPersona;
  String? _worldBackground;
  String _mode = 'summary';

  List<Message> _messages = [];
  List<SegmentSummary> _segments = [];
  bool _isPending = false;
  String _streamingContent = '';
  String? _error;

  bool _showSummaryPrompt = false;
  int? _pendingSummaryIndex;

  double _affection = 30.0;
  double _previousRawAffection = 30.0;
  bool? _affectionIncreasing; // null=no change, true=up, false=down
  // Emotion system
  EmotionState? _emotionState;
  EmotionAnalyzer? _analyzer;

  // Quick reply
  List<String> _quickReplies = [];
  bool _showQuickReplies = false;

  // Auto-continue mode (AI keeps talking)
  bool _isContinuing = false;

  List<Message> get messages => _messages;
  List<SegmentSummary> get segments => _segments;
  bool get isPending => _isPending;
  String get streamingContent => _streamingContent;
  String? get error => _error;
  String? get currentConvId => _currentConvId;
  String? get systemPrompt => _systemPrompt;
  String? get userPersona => _userPersona;
  String? get worldBackground => _worldBackground;
  String get mode => _mode;
  bool get showSummaryPrompt => _showSummaryPrompt;
  int? get pendingSummaryIndex => _pendingSummaryIndex;
  int get affection => _affection.round();
  String get providerType => _providerType;
  bool get affectionEnabled => _affectionEnabled;
  EmotionState? get emotionState => _emotionState;
  Map<String, String> get emotionLabels => _emotionState != null
      ? EmotionTables.getEmotionDescription(_emotionState!)
      : {'towards_user': '平淡', 'self_state': '平静'};
  bool get isSelfDestructMode =>
      _emotionState != null && EmotionTables.isSelfDestructMode(_emotionState!);
  List<String> get quickReplies => _quickReplies;
  bool get showQuickReplies => _showQuickReplies;
  bool get isContinuing => _isContinuing;

  ChatProvider(this._convProvider);

  void updateConvProvider(ConversationProvider provider) {
    _convProvider = provider;
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
    final chatModel = model ?? defaults['chat_model']!;

    _service = DeepSeekService(
      apiKey: key,
      endpoint: chatEndpoint,
      model: chatModel,
    );
    _analyzer = EmotionAnalyzer(_service!);

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

      _service = DeepSeekService(
        apiKey: key,
        endpoint: endpoint ?? 'https://api.deepseek.com/v1/chat/completions',
        model: model ?? 'deepseek-v4-flash',
      );
      _analyzer = EmotionAnalyzer(_service!);

      return true;
    }
    return false;
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
    _currentConvId = convId;
    _messages = await DatabaseService.getMessages(convId);
    _segments = await DatabaseService.getSegmentSummaries(convId);
    final conv = await DatabaseService.getConversation(convId);
    _systemPrompt = conv.systemPrompt;
    _userPersona = conv.userPersona;
    _worldBackground = conv.worldBackground;
    _mode = conv.mode;
    _error = null;
    _showSummaryPrompt = false;
    _pendingSummaryIndex = null;
    _showQuickReplies = false;
    _quickReplies = [];

    // Load or create emotion state, apply decay
    _emotionState = await DatabaseService.getEmotionState(convId);
    if (_emotionState == null) {
      _emotionState = EmotionState.createDefault(convId,
          initialAffection: conv.affection.toDouble());
      await DatabaseService.insertEmotionState(_emotionState!);
    } else {
      // Apply decay on load
      final now = DateTime.now();
      final elapsedOther =
          now.difference(_emotionState!.lastUpdate).inSeconds / 3600.0;
      if (elapsedOther > 0) {
        _emotionState!.currentLibidoOther = DecayCalculator.applyDecay(
            _emotionState!.currentLibidoOther,
            _emotionState!.baseLibidoOther,
            elapsedOther,
            2.0);
        _emotionState!.currentAggressionOther = DecayCalculator.applyDecay(
            _emotionState!.currentAggressionOther,
            _emotionState!.baseAggressionOther,
            elapsedOther,
            2.0);
        _emotionState!.currentLibidoSelf = DecayCalculator.applyDecay(
            _emotionState!.currentLibidoSelf,
            _emotionState!.baseLibidoSelf,
            elapsedOther,
            2.0);
        _emotionState!.currentAggressionSelf = DecayCalculator.applyDecay(
            _emotionState!.currentAggressionSelf,
            _emotionState!.baseAggressionSelf,
            elapsedOther,
            2.0);
        _emotionState!.lastUpdate = now;
      }
      _emotionState!.lastInteraction = now;
      await DatabaseService.updateEmotionState(_emotionState!);
    }
    _affection = _emotionState!.affection;
    _previousRawAffection = _emotionState!.affection;

    notifyListeners();
  }

  void newConversation() {
    _currentConvId = null;
    _messages = [];
    _segments = [];
    _streamingContent = '';
    _isPending = false;
    _error = null;
    _systemPrompt = null;
    _userPersona = null;
    _worldBackground = null;
    _showSummaryPrompt = false;
    _pendingSummaryIndex = null;
    _showQuickReplies = false;
    _quickReplies = [];
    _affection = 30.0;
    _previousRawAffection = 30.0;
    _emotionState = null;
    _affectionIncreasing = null;
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

  void setInitialAffection(int value) {
    _affection = value.clamp(-15, 100).toDouble();
    _previousRawAffection = _affection;

    if (_emotionState != null) {
      _emotionState!.affection = _affection;
    }
  }

  bool? get affectionIncreasing => _affectionIncreasing;

  /// Returns true if affection just changed (consumed on read).
  bool consumeAffectionChanged() {
    final raw = _emotionState?.affection ?? _affection;
    if ((raw.round() - _previousRawAffection.round()).abs() >= 1) {
      _affectionIncreasing = raw > _previousRawAffection;
      _previousRawAffection = raw;

      return true;
    }
    _affectionIncreasing = null;
    return false;
  }

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

  Future<void> editMessage(int index, String newContent) async {
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index].copyWith(content: newContent.trim());
    _messages[index] = msg;
    await DatabaseService.updateMessage(msg);
    notifyListeners();
  }

  Future<void> deleteMessage(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final msg = _messages[index];
    await DatabaseService.deleteMessage(msg.id);
    _messages.removeAt(index);
    notifyListeners();
  }

  Future<void> resetConversation() async {
    if (_currentConvId == null) {
      _messages = [];
      _segments = [];
      notifyListeners();
      return;
    }
    await DatabaseService.deleteMessages(_currentConvId!);
    await DatabaseService.deleteSegmentSummaries(_currentConvId!);
    _messages = [];
    _segments = [];
    _isPending = false;
    _streamingContent = '';
    _error = null;
    _showSummaryPrompt = false;
    _pendingSummaryIndex = null;

    // Reset affection and emotion to initial values
    _affection = 30.0;
    _previousRawAffection = 30.0;
    _affectionIncreasing = null;
    if (_emotionState != null) {
      _emotionState =
          EmotionState.createDefault(_currentConvId!, initialAffection: 30.0);
      await DatabaseService.updateEmotionState(_emotionState!);
    }
    // Update conversation affection in DB
    final conv = await DatabaseService.getConversation(_currentConvId!);
    final updated = conv.copyWith(affection: 30);
    await DatabaseService.updateConversation(updated);

    notifyListeners();
  }

  void clearQuickReplies() {
    _showQuickReplies = false;
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

    if (_currentConvId == null) {
      final conv = await _convProvider.createConversation(
          initialAffection: _affection.round(), mode: _mode);
      _currentConvId = conv.id;
      if (_systemPrompt != null && _systemPrompt!.isNotEmpty) {
        final updated = conv.copyWith(systemPrompt: _systemPrompt);
        await DatabaseService.updateConversation(updated);
      }
      // Create emotion state for new conversation
      _emotionState = EmotionState.createDefault(_currentConvId!,
          initialAffection: _affection);
      await DatabaseService.insertEmotionState(_emotionState!);
    }

    final userMsg = Message(
      conversationId: _currentConvId!,
      role: 'user',
      content: text.trim(),
    );
    _messages.add(userMsg);
    await DatabaseService.insertMessage(userMsg);

    _isPending = true;
    _streamingContent = '';
    notifyListeners();

    final conv = await DatabaseService.getConversation(_currentConvId!);
    if (conv.title == '新对话') {
      final t = text.trim();
      final title = t.length > 20 ? '${t.substring(0, 20)}...' : t;
      await _convProvider.updateTitle(_currentConvId!, title);
    }

    final assistantMsg = Message(
      conversationId: _currentConvId!,
      role: 'assistant',
      content: '',
    );
    _messages.add(assistantMsg);
    notifyListeners();

    // Build context via shared ContextBuilder
    final safeMode = await AuthService.getAdminSafeMode();
    final doAffectionJudge = _affectionEnabled && !safeMode;
    final contextMsgs = await ContextBuilder.build(
      conversationId: _currentConvId!,
      systemPrompt: _systemPrompt,
      conversationPrompt: conv.systemPrompt,
      userPersona: _userPersona ?? conv.userPersona,
      worldBackground: _worldBackground ?? conv.worldBackground,
      emotionState: _emotionState,
      affectionEnabled: _affectionEnabled,
      mode: _mode,
      messages: _messages,
      segments: _segments,
      injectDeltaTag: doAffectionJudge,
    );

    double? inlineDelta;
    String? inlineReason;

    try {
      // Temperature scales with affection
      final temp = 0.5 + (_affection + 15) / 115 * 1.3;
      final fullContent = await _service!.streamChatRaw(
        contextMessages: contextMsgs,
        temperature: temp,
        onToken: (token) {
          _streamingContent += token;
          var display = _streamingContent;
          // Hide trailing Δ tag during streaming.
          // Matches Δ±0, Δ+0.2, Δ-0, Δ0 etc. (both ± and ASCII +/-).
          final deltaMatch =
              RegExp(r'Δ\s*[+\-±]?\d*\.?\d*\s*[^\n]*$').firstMatch(display);
          if (deltaMatch != null) {
            display = display.substring(0, deltaMatch.start).trimRight();
          }
          _messages[_messages.length - 1] =
              assistantMsg.copyWith(content: display);
          notifyListeners();
        },
        onDone: () => _streamingContent = '',
        onError: (err) => _error = err,
      );

      // Parse and strip the Δ tag, apply immediately
      var cleanContent = fullContent;
      final inlineMatch =
          RegExp(r'Δ\s*([+\-±]?\d+\.?\d*)\s*(.*)').firstMatch(fullContent);
      if (inlineMatch != null) {
        inlineDelta =
            (double.tryParse(inlineMatch.group(1)!) ?? 0.0).clamp(-0.5, 0.8);
        inlineReason = inlineMatch.group(2)!.trim();
        cleanContent =
            cleanContent.replaceFirst(inlineMatch.group(0)!, '').trimRight();
        if (cleanContent.isEmpty) cleanContent = fullContent;
      }
      final savedMsg = assistantMsg.copyWith(content: cleanContent);
      _messages[_messages.length - 1] = savedMsg;
      await DatabaseService.insertMessage(savedMsg);

      // Update affection from inline Δ tag (skip if safe mode)
      if (inlineDelta != null && !safeMode) {
        _affection = (_affection + inlineDelta).clamp(-15.0, 100.0);
        if (_emotionState != null) {
          _emotionState!.affection = _affection;
        }
        await DatabaseService.insertAffectionLog(AffectionLog(
          id: const Uuid().v4(),
          conversationId: _currentConvId!,
          delta: inlineDelta,
          reason: inlineReason ?? '',
          createdAt: DateTime.now(),
          userMessage: text.trim(),
          aiMessage: cleanContent,
        ));
      }

      // Update conversation timestamp and affection
      final updatedConv = conv.copyWith(
          updatedAt: DateTime.now(), affection: _affection.round());
      await DatabaseService.updateConversation(updatedConv);
    } catch (e) {
      _error = '请求失败: $e';
      if (_messages.isNotEmpty &&
          _messages.last.role == 'assistant' &&
          _messages.last.content.isEmpty) {
        _messages.removeLast();
      }
    }

    _isPending = false;
    _streamingContent = '';

    await _maybeArchiveSegment();

    notifyListeners();

    // Trigger emotion analysis (unconscious LLM) every round
    if (inlineDelta != null) {
      // Δ tag already handled affection — just update emotion values
      _previousRawAffection = _affection;
    }
    if (_affectionEnabled &&
        _analyzer != null &&
        _emotionState != null &&
        !safeMode) {
      Future.delayed(const Duration(milliseconds: 300),
          () => _doEmotionAnalysis(text.trim()));
    }
    // Generate quick replies via separate API call (every round, all providers)
    if (_service != null) {
      final aiMsgs = _messages
          .where((m) => m.role == 'assistant' && m.content.isNotEmpty)
          .toList();
      if (aiMsgs.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 400),
            () => _generateQuickReplies(aiMsgs.last.content));
      }
    }
  }

  /// Unified emotion analysis via unconscious LLM.
  /// Called after every AI reply. Updates both emotion values and affection.
  Future<void> _doEmotionAnalysis(String userMessage) async {
    if (_currentConvId == null ||
        !_affectionEnabled ||
        _analyzer == null ||
        _emotionState == null) return;

    try {
      final allMsgs = _messages.where((m) => m.content.isNotEmpty).toList();
      final aiMsgs = allMsgs.where((m) => m.role == 'assistant').toList();
      final lastAiMsg = aiMsgs.isNotEmpty ? aiMsgs.last.content : '';

      final history = allMsgs.map((m) => '${m.role}: ${m.content}').join('\n');

      final deltas = await _analyzer!.analyzeAndAdjust(
        state: _emotionState!,
        history: history,
        latestMsg: userMessage,
      );

      final sensitivity = await AuthService.getEmotionSensitivity();

      // Update 4 emotion values only (affection handled by Δ tag)
      final lo = (deltas['libido_other_delta'] as double) * sensitivity;
      final ao = (deltas['aggression_other_delta'] as double) * sensitivity;
      final ls = (deltas['libido_self_delta'] as double) * sensitivity;
      final as_ = (deltas['aggression_self_delta'] as double) * sensitivity;

      _emotionState!.currentLibidoOther =
          (_emotionState!.currentLibidoOther + lo).clamp(0.0, 50.0);
      _emotionState!.currentAggressionOther =
          (_emotionState!.currentAggressionOther + ao).clamp(0.0, 50.0);
      _emotionState!.currentLibidoSelf =
          (_emotionState!.currentLibidoSelf + ls).clamp(0.0, 50.0);
      _emotionState!.currentAggressionSelf =
          (_emotionState!.currentAggressionSelf + as_).clamp(0.0, 50.0);

      _emotionState!.baseLibidoOther = (_emotionState!.baseLibidoOther +
              (deltas['base_libido_other_delta'] as double) * sensitivity)
          .clamp(0.0, 50.0);
      _emotionState!.baseAggressionOther = (_emotionState!.baseAggressionOther +
              (deltas['base_aggression_other_delta'] as double) * sensitivity)
          .clamp(0.0, 50.0);
      _emotionState!.baseLibidoSelf = (_emotionState!.baseLibidoSelf +
              (deltas['base_libido_self_delta'] as double) * sensitivity)
          .clamp(0.0, 50.0);
      _emotionState!.baseAggressionSelf = (_emotionState!.baseAggressionSelf +
              (deltas['base_aggression_self_delta'] as double) * sensitivity)
          .clamp(0.0, 50.0);

      _emotionState!.turnCount++;
      _emotionState!.lastUpdate = DateTime.now();
      _emotionState!.lastInteraction = DateTime.now();

      await DatabaseService.updateEmotionState(_emotionState!);

      // Log emotion deltas (no affection, no reason — those come from Δ tag)
      await DatabaseService.insertEmotionLog(EmotionLog(
        id: const Uuid().v4(),
        conversationId: _currentConvId!,
        libidoOtherDelta: lo,
        aggressionOtherDelta: ao,
        libidoSelfDelta: ls,
        aggressionSelfDelta: as_,
        intensity: (deltas['intensity'] as double),
        userMessage: userMessage,
        aiMessage: lastAiMsg,
      ));

      notifyListeners();
    } catch (e) {
      print('[EmotionAnalysis] 潜意识分析失败，下轮重试: $e');
    }
  }

  /// Generate quick reply suggestions. Uses a separate API call with
  /// role-switch system prompt to avoid character-perspective bias.
  Future<void> _generateQuickReplies(String lastAiContent) async {
    if (_service == null || _currentConvId == null) return;
    _showQuickReplies = true;
    notifyListeners();
    try {
      final tone = await AuthService.getQuickReplyTone();
      final toneGuide = tone == '下流'
          ? '语气粗俗带脏话'
          : tone == '优雅'
              ? '语气文雅有修养'
              : '语气自然日常';
      // Grab recent exchanges for context
      final allMsgs = _messages.where((m) => m.content.isNotEmpty).toList();
      final recent =
          allMsgs.length > 6 ? allMsgs.sublist(allMsgs.length - 6) : allMsgs;
      final context = recent
          .map((m) => '${m.role == 'user' ? '用户' : '角色'}: ${m.content}')
          .join('\n');
      final prompt = '对话：\n$context\n\n'
          '根据以上对话，生成用户接下来可能对角色说的2个回复选项：\n'
          '1. safe（保守）：自然跟随剧情，15字以内\n'
          '2. novel（创意）：更有想象力但不偏离，15字以内\n'
          '$toneGuide\n'
          '只输出JSON：{"safe":"...","novel":"..."}';
      final result = await _service!
          .chatRaw(prompt,
              '你不是角色。你是快捷回复助手，替【用户】生成回复，发送给【角色】。站在用户视角，生成用户对角色说的话。只输出JSON，不要解释。')
          .timeout(const Duration(seconds: 10));
      final json = _extractJson(result);
      if (json != null) {
        final safe = json['safe'] as String? ?? '';
        final novel = json['novel'] as String? ?? '';
        if (safe.isNotEmpty && novel.isNotEmpty) {
          _quickReplies = [safe, novel];
        }
      }
    } catch (e) {
      print('[QuickReply] 快捷回复生成失败: $e');
      _quickReplies = [];
      _showQuickReplies = false;
    }
    notifyListeners();
  }

  Map<String, dynamic>? _extractJson(String text) =>
      JsonUtils.extractJson(text);

  /// Send a quick reply as user message.
  Future<void> sendQuickReply(String text) async {
    _showQuickReplies = false;
    _quickReplies = [];
    notifyListeners();
    await sendMessage(text);
  }

  /// Let AI continue without user input (no visible user message).
  Future<void> sendContinueCommand() async {
    if (_isPending ||
        _isContinuing ||
        _service == null ||
        _currentConvId == null) return;
    _isContinuing = true;
    _showQuickReplies = false;
    _quickReplies = [];
    _isPending = true;
    _streamingContent = '';
    notifyListeners();

    try {
      final assistantMsg = Message(
        conversationId: _currentConvId!,
        role: 'assistant',
        content: '',
      );
      _messages.add(assistantMsg);
      notifyListeners();

      // Build context via shared ContextBuilder (no Δ tag, inject continue)
      final conv = await DatabaseService.getConversation(_currentConvId!);
      final contextMsgs = await ContextBuilder.build(
        conversationId: _currentConvId!,
        systemPrompt: _systemPrompt,
        conversationPrompt: conv.systemPrompt,
        userPersona: _userPersona ?? conv.userPersona,
        worldBackground: _worldBackground ?? conv.worldBackground,
        emotionState: _emotionState,
        affectionEnabled: _affectionEnabled,
        mode: _mode,
        messages: _messages,
        segments: _segments,
        injectContinue: true,
      );

      final temp = 0.5 + (_affection.round() + 15) / 115 * 1.3;
      final fullContent = await _service!.streamChatRaw(
        contextMessages: contextMsgs,
        temperature: temp,
        onToken: (token) {
          _streamingContent += token;
          var display = _streamingContent;
          final deltaMatch =
              RegExp(r'Δ\s*[+\-±]?\d*\.?\d*\s*[^\n]*$').firstMatch(display);
          if (deltaMatch != null) {
            display = display.substring(0, deltaMatch.start).trimRight();
          }
          _messages[_messages.length - 1] =
              assistantMsg.copyWith(content: display);
          notifyListeners();
        },
        onDone: () => _streamingContent = '',
      );

      final savedMsg = assistantMsg.copyWith(content: fullContent);
      _messages[_messages.length - 1] = savedMsg;
      await DatabaseService.insertMessage(savedMsg);

      final updatedConv = conv.copyWith(updatedAt: DateTime.now());
      await DatabaseService.updateConversation(updatedConv);
    } catch (e) {
      _error = '请求失败: $e';
      if (_messages.isNotEmpty &&
          _messages.last.role == 'assistant' &&
          _messages.last.content.isEmpty) {
        _messages.removeLast();
      }
    }

    _isPending = false;
    _streamingContent = '';
    _isContinuing = false;
    await _maybeArchiveSegment();
    notifyListeners();
    // Generate quick replies after continue (no Δ/emotion analysis for continue)
    if (_service != null) {
      final aiMsgs = _messages
          .where((m) => m.role == 'assistant' && m.content.isNotEmpty)
          .toList();
      if (aiMsgs.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 400),
            () => _generateQuickReplies(aiMsgs.last.content));
      }
    }
  }

  Future<void> _maybeArchiveSegment() async {
    if (_currentConvId == null) return;

    final unarchived = <Message>[];
    for (final m in _messages) {
      if (m.content.isNotEmpty && m.segmentIndex == null) {
        unarchived.add(m);
      }
    }

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
        final archiveText = toArchive
            .map((m) => '${m.role == 'user' ? '用户' : 'AI'}: ${m.content}')
            .join('\n');

        // Build in-character diary-style summary prompt using persona
        final persona =
            (_systemPrompt != null && _systemPrompt!.trim().isNotEmpty)
                ? _systemPrompt!.trim()
                : null;
        final systemPrompt = persona != null
            ? '$persona\n\n现在，你正在写日记，以第一人称「我」的口吻回顾刚才发生的事。你必须完全保持设定中的性格、语气和说话风格。日记内容要像角色本人写的，不要像第三人称总结。'
            : '你是总结助手。请用第一人称「我」的口吻回顾以下对话，保持角色的性格和语气。';
        final userPrompt = persona != null
            ? '用你的口吻，以第一人称写一段简短的日记（不超过200字），回顾以下对话中发生的事：\n\n$archiveText'
            : '请用不超过200字的第一人称总结以下对话要点：\n\n$archiveText';

        final result = await _service!.chatRaw(userPrompt, systemPrompt);
        final trimmed = result.trim();
        if (trimmed.isNotEmpty) {
          final updated = summary.copyWith(content: trimmed);
          await DatabaseService.updateSegmentSummary(updated);
          final idx =
              _segments.indexWhere((s) => s.segmentIndex == segmentIndex);
          if (idx != -1) _segments[idx] = updated;
        }
      } catch (e) {
        print('[Summary] AI 总结生成失败: $e');
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
