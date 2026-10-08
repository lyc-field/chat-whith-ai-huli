# Structured Reply JSON Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace visible `Δ` and `[快捷回复]` suffixes with a resilient structured reply envelope while keeping streaming正文-only display and preserving extension fields.

**Architecture:** Add a pure `StructuredReplyParser` that understands the JSON envelope, partial streaming JSON, and legacy output as a hidden compatibility fallback. `ChatProvider` stores/displays only the parsed `reply`; affection and quick replies come from metadata. `ContextBuilder` instructs the model to return one JSON object and never emits legacy suffix instructions.

**Tech Stack:** Flutter/Dart, existing DeepSeek-compatible streaming API, Flutter tests.

---

### Task 1: Add parser and prompt regression tests

**Files:**
- Create: `test/services/structured_reply_test.dart`

- [ ] **Step 1: Write failing tests**

Cover valid JSON, fenced/extra-text JSON, clamping `affection_delta` to `-0.3..0.8`, two quick replies, partial streaming正文 extraction, malformed fallback, and legacy suffix sanitization.

- [ ] **Step 2: Run focused tests**

Run: `flutter test test/services/structured_reply_test.dart`

Expected: FAIL because the parser does not exist.

### Task 2: Implement resilient structured reply parser

**Files:**
- Create: `lib/services/structured_reply.dart`
- Test: `test/services/structured_reply_test.dart`

- [ ] **Step 1: Implement `StructuredReply` and `StructuredReplyParser`**

Keep unknown JSON fields in `extra`, parse only `reply`, `affection_delta`, `affection_reason`, and `quick_replies`, and return safe正文 for partial/malformed responses.

- [ ] **Step 2: Run focused tests**

Run: `flutter test test/services/structured_reply_test.dart`

Expected: PASS.

### Task 3: Replace model instructions with JSON envelope

**Files:**
- Modify: `lib/services/context_builder.dart`
- Modify: `lib/providers/chat_provider.dart`
- Modify: `lib/services/affection_manager.dart`
- Modify: `test/services/affection_manager_test.dart`

- [ ] **Step 1: Remove Δ and `[快捷回复]` instruction injection**

Inject one JSON schema instruction with a conditional affection field and quick-reply tone rules. Use a four-round deterministic affection cadence after the initial relationship period.

- [ ] **Step 2: Update affection range/cadence**

Use `-0.3..0.8`; judge at rounds 4, 8, 12, …, while keeping the old parser only as an invisible compatibility fallback.

- [ ] **Step 3: Run focused tests**

Run: `flutter test test/services/affection_manager_test.dart`

Expected: PASS.

### Task 4: Make streaming display正文-only

**Files:**
- Modify: `lib/providers/chat_provider.dart`
- Modify: `lib/services/structured_reply.dart`

- [ ] **Step 1: Feed stream chunks through the parser**

Display only the partial `reply` string. Keep raw JSON hidden until parsing completes.

- [ ] **Step 2: Finalize metadata**

Apply `affection_delta` and `affection_reason` from parsed JSON; set quick replies from `quick_replies`; on parse failure show sanitized正文 and leave metadata empty.

- [ ] **Step 3: Update minimum-length continuation**

Use the same正文-only decoder so JSON wrappers can never leak during fill-in requests.

### Task 5: Verify and document

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Run `flutter test`**
- [ ] **Step 2: Run `dart analyze lib/`**
- [ ] **Step 3: Run `git diff --check`**
- [ ] **Step 4: Update progress and commit the implementation**

