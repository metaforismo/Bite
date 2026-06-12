# Architecture

This document explains how a single message travels through Bite, and how the proactive pieces work. It complements the high level overview in the root [README](../README.md).

## The agent loop

```
iOS app (SwiftUI)                Cloudflare Worker
─────────────────                ─────────────────
user types a message  ──POST──▶  /v1/chat/stream (SSE)
                                 1. auth middleware verifies the Firebase JWT
                                 2. context builder loads profile, recent data,
                                    relevant memories (Vectorize search)
                                 3. model call with the tool registry attached
                                 4. tool calls execute server side against D1
                                    (every tool input/output is Zod validated)
                                 5. text deltas, thinking states and artifacts
                                    stream back as SSE events
UI renders streaming  ◀──SSE──   6. after the turn, a fast model pass extracts
text, tool receipts                 new user facts, dedupes them by embedding
and artifact cards                  similarity, and stores the novel ones
```

Key decision: **the model never touches the database directly**. Every read and write goes through one of the 29 typed tools in `worker/src/tools/`. Each tool declares its input and output schema with Zod, so a malformed model call fails loudly instead of corrupting state, and every tool is unit testable in isolation.

## Model routing

`worker/src/llm/router.ts` is a thin wrapper around the OpenAI SDK pointed at OpenRouter. Tools pick a tier, not a vendor string:

| Tier | Default model | Used for |
|---|---|---|
| `primary` | `openai/gpt-5.5` | Coach conversations, plans, workouts |
| `mid` | `openai/gpt-5.4` | Structured extraction (macros, lab parsing) |
| `cheap` | `openai/gpt-5.4-mini` | Memory extraction, classification, triage |
| `vision` | `openai/gpt-5.4` | Meal photos, lab document images |

Embeddings use `openai/text-embedding-3-small` (`worker/src/llm/embed.ts`). Swapping any tier is a one line change.

## Memory

After every assistant turn, `worker/src/llm/memory.ts` runs a cheap pass that proposes zero to three stable user facts (goals, preferences, barriers). Each candidate is deduplicated twice: first by exact text, then by cosine similarity above 0.92 against existing memory embeddings in Vectorize. Only novel facts are stored, and they are injected as context in future conversations. This keeps memory high signal instead of accumulating noise.

## Proactive pieces

* **Scheduled check ins** (`worker/src/tools/scheduleCheckIn.ts`): the agent can schedule a recurring question. The worker stores the cadence and returns an alarm payload that the iOS client registers with AlarmKit, so the nudge fires locally even offline.
* **Impact analysis** (`analyzeImpact`, `analyzeImpactByTag`): correlates journal tags with HealthKit sleep and recovery metrics, so coach claims like "alcohol is hurting your deep sleep" are backed by the user's own data.
* **Biological age** (`computeBiologicalAge`): an estimate from biomarkers and habits, recomputed when new labs arrive.

## Lab report pipeline

`worker/src/jobs/analyze.ts`: the user uploads a PDF or photo. Files are encrypted client side of the API boundary with a per user AES GCM key (derived in `worker/src/encryption.ts`) and stored in R2. The pipeline decrypts, extracts text (or hands the image to the vision tier), asks the mid tier for a strict JSON list of biomarkers with reference ranges, and persists `lab_reports` and `biomarkers` rows. The coach can then reason about labs in chat.

## Privacy posture

* Health data is stored per user and encrypted at the file level with per user keys.
* The worker only ever sends the model the minimal context a tool needs.
* Secrets live in Wrangler secrets, never in the repo.
* Lab summaries are framed as "discuss with your clinician", not diagnoses.

## iOS app structure

```
Bite/Views/        Screen per folder (Today, Coach, Journal, Fitness, Biology, ...)
Bite/ViewModels/   Observable view models (chat state machine lives here)
Bite/Services/     HealthKit, API client, SSE parser, notifications, speech
Bite/Models/       SwiftData models + Codable DTOs shared with the worker
Bite/Design/       Design system: tokens, type scale, glass cards, motion
BiteWidgets/       Home Screen widgets + workout Live Activity
```

The chat UI renders **artifacts**: typed cards (food cart, workout, training plan, lab report, check in, charts) emitted by tools during a turn. `ArtifactRouterView` maps artifact types to SwiftUI cards, so a new tool with a new artifact only needs a card view and a router case.
