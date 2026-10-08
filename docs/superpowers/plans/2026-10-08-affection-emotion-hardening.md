# Affection and Emotion Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make affection and emotion state consistent, persist immediately, evaluate affection only after four-round summaries, scale emotion changes by intensity, remove obsolete decay configuration, and prevent stale requests from corrupting conversations.

**Architecture:** Keep the existing `AffectionManager` and `ChatProvider` APIs where possible, but introduce pure helpers for four-round judging and intensity limits. Persona-scoped affection remains the source of truth for new-format conversations; legacy conversation-level affection remains supported. All asynchronous writes use a fixed conversation/persona snapshot and are guarded before every database mutation.

**Tech Stack:** Flutter/Dart, Provider, sqflite, existing service/test architecture.

---

### Task 1: Restore and lock the safe baseline

**Files:**
- Modify: `lib/services/auth_service.dart`
- Modify: `lib/services/content_safety_service.dart`
- Test: `test/services/immersive_roleplay_test.dart`

- [ ] **Step 1: Remove the uncommitted empty-regex branch**
- [ ] **Step 2: Restore the higher-priority safety wording in the default prompts**
- [ ] **Step 3: Run the immersive safety tests**

Run: `flutter test test/services/immersive_roleplay_test.dart`

Expected: 3 tests pass.

### Task 2: Add affection persistence and cadence tests

**Files:**
- Modify: `test/services/affection_manager_test.dart`
- Create: `test/services/affection_judgement_test.dart`

- [ ] **Step 1: Test four-round batch judging**

Four user rounds are collected; the judgement is triggered only at the fourth round and receives the batch summary.

- [ ] **Step 2: Test reason normalization**

Reasons must be 15–30 characters, single-line, non-empty, and truncated safely.

- [ ] **Step 3: Test intensity limits**

Low intensity allows zero deltas, normal intensity limits current emotion deltas to ±0.1, and high intensity permits the configured larger range.

- [ ] **Step 4: Run focused tests and confirm RED**

Run: `flutter test test/services/affection_manager_test.dart test/services/affection_judgement_test.dart`

Expected: new tests fail before implementation.

### Task 3: Implement four-round affection judgement and immediate persistence

**Files:**
- Modify: `lib/services/affection_manager.dart`
- Modify: `lib/providers/chat_provider.dart`
- Modify: `lib/services/emotion_service.dart`
- Test: `test/services/affection_judgement_test.dart`

- [ ] **Step 1: Add a four-round batch buffer**

Collect user/assistant pairs without changing affection on intermediate rounds. At round 4, summarize the four rounds and perform one judgement.

- [ ] **Step 2: Normalize and persist affection deltas**

Clamp `-0.3..0.8`, normalize the reason to 15–30 single-line characters, and immediately save persona affection plus persona emotion state before starting delayed unconscious analysis.

- [ ] **Step 3: Apply intensity-aware emotion limits**

Use intensity from the emotion analyzer:

```text
0.5: zero allowed, current deltas capped at ±0.05
1.0: current deltas capped at ±0.1
2.0: current deltas capped at ±2.0
```

Preserve the existing baselines and sensitivity behavior otherwise.

- [ ] **Step 4: Run focused tests**

Expected: PASS.

### Task 4: Rename user-facing libido semantics without changing stored compatibility

**Files:**
- Modify: `lib/services/emotion_service.dart`
- Modify: `lib/pages/emotion_detail_page.dart`
- Modify: `lib/widgets/emotion_grid.dart`
- Modify: `lib/services/context_builder.dart`
- Test: `test/services/emotion_service_test.dart`

- [ ] **Step 1: Keep stored field names for database compatibility**
- [ ] **Step 2: Change user-facing labels to closeness/attachment language**
- [ ] **Step 3: Ensure prompts describe ordinary affection separately from sexual content**
- [ ] **Step 4: Run emotion and UI-adjacent tests**

### Task 5: Remove obsolete decay configuration

**Files:**
- Modify: `lib/services/auth_service.dart`
- Modify: `lib/pages/admin_panel_page.dart`
- Modify: `lib/services/affection_manager.dart`
- Modify: `test/services/emotion_service_test.dart`

- [ ] **Step 1: Remove decay settings accessors and unused UI**
- [ ] **Step 2: Remove disabled decay implementation and related tests**
- [ ] **Step 3: Run analyzer and focused tests**

### Task 6: Harden async writes and regeneration

**Files:**
- Modify: `lib/providers/chat_provider.dart`
- Modify: `lib/services/affection_manager.dart`
- Modify: `test/services/request_guard_test.dart`
- Create: `test/services/chat_provider_state_test.dart`

- [ ] **Step 1: Guard affection persistence with fixed conversation/persona snapshots**
- [ ] **Step 2: Guard archive generation and summary writes**
- [ ] **Step 3: Regenerate by deleting the selected assistant message and all later messages before replaying**
- [ ] **Step 4: Add tests for session switching and middle-turn regeneration**
- [ ] **Step 5: Run focused tests**

### Task 7: Final verification and report

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run `flutter test`**
- [ ] **Step 2: Run `dart analyze lib/`**
- [ ] **Step 3: Run `git diff --check`**
- [ ] **Step 4: Review database writes for legacy/new-format compatibility**
- [ ] **Step 5: Update progress and commit**

