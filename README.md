# 小狐爱说话

Flutter AI 角色扮演聊天应用，具备好感度系统与弗洛伊德情感引擎。

## 技术栈

- Flutter (Dart) + Material 3 + Provider
- SQLite (sqflite) v17 (FTS5 全文搜索)
- DeepSeek API（兼容 OpenAI 格式）
- 平台：Android / iOS / Windows / macOS / Linux / Web

## 核心功能

### 角色扮演
- 多角色人设系统：名称、身份、性格、外观、补充信息，支持多角色切换
- 用户人设 + 世界背景 + 开场白
- 导出/导入角色包（加密 .json 格式，内容不可直接阅读）
- 管理员全局安全规则

### 好感度系统
- 范围 -15 ~ 100，每轮 Δ 变化 -0.5 ~ +0.8
- AI 回复末尾自动附加 Δ 标记，系统解析隐藏
- 点击爱心图标查看完整变化历史
- 好感度联动 AI temperature（越高越有创造性）

### 情感系统（弗洛伊德模型）
- 4 维度：他力比多 / 他攻击性 / 自力比多 / 自攻击性
- 潜意识 LLM 每轮分析对话，自动更新情感数值
- 5×5 情绪网格可视化
- 离线衰减：情感逐渐回归基线
- 情感面板作为独立系统消息注入，优先级最高

### 上下文管理
- **总结模式**：40 条消息（20 轮）触发归档，每次归档 16 条（8 轮），AI 以角色口吻写日记式总结
- **书签模式**：手动标记关键消息对，永久注入上下文

### 对话管理
- 多对话切换，自动生成标题
- 消息编辑 / 删除 / 复制
- 重置对话（清空消息 + 好感度回归配置的初始值）
- 对话头像自定义

### 快捷回复 & 继续
- 每轮 AI 回复后自动生成 2 个快捷回复选项
- 三档语气（下流 / 正常 / 优雅）
- 继续按钮：AI 自行推进剧情

### 管理面板
- 入口：点击顶部 🐾 图标连续 6 次
- 全局安全规则 / 安心模式
- 各对话四维情感手动调节
- 情感灵敏度 + 衰减时长配置
- 默认初始好感度设置

## 项目结构

```
lib/
├── models/          # AIPersona, Conversation, Message, EmotionState, AffectionLog
├── providers/       # ChatProvider, ConversationProvider, PersonaProvider
├── services/        # DeepSeekService, DatabaseService, EmotionService, ContextBuilder, PersonaIO, AffectionManager
├── pages/           # ChatPage, HomePage, AdminPanelPage, PersonaSettingsPage 等
└── widgets/         # ChatBubble, ConversationTile, MessageInput, EmotionGrid 等
```

## 运行

```bash
flutter pub get
flutter run
```

## 测试

```bash
flutter test
```

## 打包

```bash
flutter build apk --release
```
