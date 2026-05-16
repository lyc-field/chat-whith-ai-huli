# 小狐爱说话

Flutter AI 聊天应用，支持角色扮演、好感度系统、弗洛伊德情感引擎。

## 技术栈

- Flutter (Dart) + Material 3 + Provider
- SQLite (sqflite) 本地存储
- DeepSeek API（兼容 OpenAI 格式）
- 平台：Android / iOS / Windows / macOS / Linux / Web

## 核心功能

### 角色扮演
- 自定义 AI 角色人设 + 用户人设
- JSON 文件导入人设（兼容简单格式和游戏导出格式）
- 管理员可设全局安全规则
- 三档快捷回复语气（下流 / 正常 / 优雅），可拖动浮窗切换

### 好感度系统
- 范围 -15 ~ 100，每轮 Δ 变化 -0.5 ~ +0.8
- AI 在回复中自动输出 Δ 标记，实时解析更新
- 爱心闪烁动画，点击查看变化历史

### 情感系统（弗洛伊德模型）
- 4 维度：他力比多 / 他攻击性 / 自力比多 / 自攻击性
- 潜意识 LLM 每轮分析对话，更新情感数值
- 5×5 情绪网格可视化
- 衰减机制：离线后情感逐渐回归基线

### 上下文管理
- **总结模式**：40 条消息（20 轮）触发归档，AI 以角色口吻写日记式总结
- **书签模式**：手动标记关键消息，永久注入上下文，适合长对话保人设

### 对话管理
- 多对话切换，自动以首条消息前 20 字命名
- 消息编辑 / 删除 / 复制
- 重置对话（清空消息 + 好感度回归初始值）
- 对话标题修改

### 快捷回复
- 每轮 AI 回复后自动生成 2 个用户回复选项
- 继续按钮：AI 自行推进剧情（不触发好感度变化）

### 管理面板
- 隐藏入口（API 设置中空 Key 连续 6 击确认）
- 全局安全人设 / 安心模式 / 情感调节
- 情感灵敏度 + 衰减时长配置

## 项目结构

```
lib/
├── models/          # Conversation, Message, EmotionState, etc.
├── providers/       # ChatProvider, ConversationProvider
├── services/        # DeepSeek API, SQLite, Auth, Emotion, Context
├── pages/           # 各页面
└── widgets/         # ChatBubble, MessageInput, EmotionGrid, etc.
```

## 运行

```bash
flutter pub get
flutter run
```

## 打包

```bash
flutter build apk --release
```
