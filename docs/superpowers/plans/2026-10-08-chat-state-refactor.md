# Chat State Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve all existing conversations while separating chat responsibilities, unifying persona-scoped emotion state access, preventing stale asynchronous replies from mutating the active chat, and presenting emotion state in user-friendly terms.

**Architecture:** Keep `ChatProvider` as the public UI-facing controller, but move request lifecycle, emotion persistence, and emotion presentation into focused services/models. Existing `emotion_states` rows remain readable; persona conversations are normalized into `persona_emotion_states` on load, with the old conversation-level row retained as a compatibility source. Every asynchronous pipeline captures a session generation and conversation/persona identity before it can write state.

**Tech Stack:** Flutter/Dart, Provider, sqflite, existing service/provider architecture, Flutter tests.

---

### Task 1: Add regression tests for emotion migration and request generations

**Files:**
- Create: `test/services/emotion_state_repository_test.dart`
- Create: `test/services/request_guard_test.dart`

- [ ] **Step 1: Write failing tests**

Test that a legacy conversation state can be converted to a persona-scoped state without losing values, and that an invalidated request cannot commit.

- [ ] **Step 2: Run the focused tests and confirm expected failures**

Run: `flutter test test/services/emotion_state_repository_test.dart test/services/request_guard_test.dart`

Expected: FAIL because the new repository and request guard do not exist.

### Task 2: Implement request lifecycle protection

**Files:**
- Create: `lib/services/request_guard.dart`
- Modify: `lib/providers/chat_provider.dart`
- Test: `test/services/request_guard_test.dart`

- [ ] **Step 1: Implement a generation-based guard**

Expose `begin()`, `invalidate()`, and `isCurrent(RequestToken)` with conversation/persona snapshot fields.

- [ ] **Step 2: Run focused tests**

Run: `flutter test test/services/request_guard_test.dart`

Expected: PASS.

- [ ] **Step 3: Integrate guard into conversation switches, reset, send, stream callbacks, and delayed emotion analysis**

All asynchronous callbacks must return without mutating messages, emotion state, or database rows when the token is stale.

### Task 3: Unify emotion state access with backward-compatible migration

**Files:**
- Create: `lib/services/emotion_state_repository.dart`
- Modify: `lib/services/database_service.dart`
- Modify: `lib/providers/chat_provider.dart`
- Modify: `lib/services/affection_manager.dart`
- Test: `test/services/emotion_state_repository_test.dart`

- [ ] **Step 1: Implement repository APIs**

Provide `loadForConversation`, `loadForPersona`, `ensureForPersona`, `save`, and `deleteForConversation`.

- [ ] **Step 2: Migrate a legacy row on persona load**

When a conversation has personas and no persona-scoped row exists, clone the legacy state into the active persona row, preserving affection, baselines, current values, turn count, and timestamps. Do not delete the legacy row.

- [ ] **Step 3: Route provider/affection manager reads and writes through the repository**

The public behavior remains unchanged while all new-format writes target `persona_emotion_states`.

- [ ] **Step 4: Run focused and existing service tests**

Run: `flutter test test/services/emotion_state_repository_test.dart test/services/affection_manager_test.dart`

Expected: PASS.

### Task 4: Extract chat pipeline responsibilities

**Files:**
- Create: `lib/services/chat_request_service.dart`
- Create: `lib/services/chat_memory_service.dart`
- Modify: `lib/providers/chat_provider.dart`
- Test: `test/services/chat_request_service_test.dart`

- [ ] **Step 1: Add tests for request snapshot validation and memory archive selection**

- [ ] **Step 2: Extract request/context preparation and memory archive selection without changing UI-facing provider methods**

- [ ] **Step 3: Run focused tests and full service tests**

Run: `flutter test`

Expected: PASS.

### Task 5: Simplify emotion presentation

**Files:**
- Create: `lib/services/emotion_presentation_service.dart`
- Modify: `lib/pages/emotion_detail_page.dart`
- Modify: `lib/widgets/emotion_grid.dart`
- Test: `test/services/emotion_presentation_service_test.dart`

- [ ] **Step 1: Write tests for relationship tier, readable state labels, and trend description**

- [ ] **Step 2: Implement presentation mapping**

Keep the existing 5×5 technical grids available under an “高级详情” section.

- [ ] **Step 3: Update the page**

Lead with relationship tier, current feeling, trend, and a short explanation; retain raw dimensions below.

- [ ] **Step 4: Run analyzer and full tests**

Run: `dart analyze lib/` and `flutter test`

Expected: no errors and all tests pass.

### Task 6: Final verification and progress report

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run `dart analyze lib/`**
- [ ] **Step 2: Run `flutter test`**
- [ ] **Step 3: Review the diff for data-loss or stale-write risks**
- [ ] **Step 4: Update `progress.md` with completed work and any remaining limitations**

