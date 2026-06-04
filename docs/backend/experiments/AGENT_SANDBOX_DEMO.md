# Agent Sandbox V1 (Backend Debug)

## Goal
Current stage focuses only on a testable bot-agent sandbox:
1. Input question
2. Input six ritual results
3. Call Qwen on SiliconFlow
4. Get structured interpretation JSON + chat-style visible answer

## Core Files
- `frontend/lib/main_agent_sandbox.dart`
- `frontend/lib/ui/screens/agent_sandbox_debug_screen.dart`
- `frontend/lib/services/liuyao_agent_v1_service.dart`
- `frontend/lib/agent_v1/engine/liuyao_parser.dart`
- `frontend/lib/agent_v1/engine/liuyao_prompt_builder.dart`
- `frontend/lib/agent_v1/models/liuyao_models.dart`
- `frontend/assets/mock/liuyao_system_prompt.md`
- `frontend/assets/mock/liuyao_few_shot_examples.json`

## Response Style Rules (Current V1)
1. Core identity: a Liuyao interpreter first, with psychological insight as support.
2. Initial reply must complete: hexagram analysis -> user context mapping -> quote -> quote relevance -> light guidance.
3. Follow-up reply should continue context naturally; no repeated full template every turn.
4. Keep resonance and readability; avoid rigid terminology dump.
5. Minimal safety only: no high-risk professional replacement, no deterministic promises.

## What Changed In This Round
1. Rebuilt `liuyao_prompt_builder` with explicit turn-based requirements.
2. Strengthened prompt constraints for long-form initial output (4+ paragraphs).
3. Added strict JSON schema constraints (including movingLines semantics).
4. Added multi-pass repair workflow: when output is invalid, ask Qwen to regenerate up to 5 attempts.
5. Added length-focused repair prompt for short answers (Qwen expands content directly, no local overwrite).
5. Removed local content fallback/overwrite logic.
6. Backend now keeps only structural parsing and quality validation.
7. Replaced few-shot examples to align with resonance-style long-form writing.

## Important Backend Policy
1. Content body must come from Qwen output.
2. Backend is not allowed to locally rewrite `answer` / `analysis` / `followups`.
3. If output is invalid, backend retries with a repair prompt (up to 5 attempts).
4. If still invalid, backend returns an error instead of local text replacement.

## How To Start
```bash
cd frontend
flutter run -d edge -t lib/main_agent_sandbox.dart
```

## Required Inputs Before Sending
1. Enable `LLM enabled`
2. Fill `SiliconFlow API Key`
3. Confirm `Qwen Model` (default: `Qwen/Qwen2.5-7B-Instruct`)
4. Enter question and six ritual values

If API key/model is missing, page will block the request and show error.

## Debug Visibility
The debug page shows:
1. User messages and agent messages in chat format
2. Current hexagram summary (original / moving / changed)
3. Quote + quote relevance
4. Follow-up suggestions
5. Raw JSON for each agent response

