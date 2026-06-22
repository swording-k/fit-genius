# MiniMax Provider Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route FitGenius AI through MiniMax-M3 while keeping released clients compatible and preserving an environment-only Aliyun rollback.

**Architecture:** `/api/ai/chat` delegates provider resolution and model mapping to a small backend module. The iOS client adopts neutral model aliases, while the backend continues accepting legacy Qwen aliases. MiniMax receives `reasoning_split: true` so existing streaming clients render only final content.

**Tech Stack:** Node.js 24/Vercel Functions, native `fetch`, Node test runner, Swift/iOS 17, Vercel environment variables.

---

### Task 1: Provider Configuration Contract

**Files:**
- Create: `backend/aiProviderConfig.mjs`
- Test: `backend/tests/aiProviderConfig.test.mjs`

- [ ] Write tests asserting `AI_PROVIDER=minimax` resolves the China endpoint, `MiniMax-M3`, `MINIMAX_API_KEY`, and maps legacy/new aliases to the configured model.
- [ ] Run `node --test backend/tests/aiProviderConfig.test.mjs` and confirm failure because the module is absent.
- [ ] Implement `resolveAIProviderConfig(env)` and `resolveUpstreamModel(requestedModel, config)` with MiniMax and Aliyun branches.
- [ ] Re-run the focused test and confirm it passes.

### Task 2: Proxy MiniMax Compatibility

**Files:**
- Modify: `api/ai/chat.js`
- Modify: `backend/tests/aiChatProxy.test.mjs`

- [ ] Replace Aliyun-only test setup with explicit provider environments.
- [ ] Add failing assertions for MiniMax endpoint, alias mapping, multimodal message passthrough, `reasoning_split: true`, streaming passthrough, and Aliyun rollback.
- [ ] Run `node --test backend/tests/aiChatProxy.test.mjs` and confirm failures identify the old hard-coded Aliyun behavior.
- [ ] Inject provider config into `createAIChatHandler`, build the upstream body from the selected provider, and preserve existing auth/error/stream semantics.
- [ ] Re-run focused and full backend tests.

### Task 3: Provider-Neutral iOS Routing

**Files:**
- Modify: `FitGenius/Services/AIModelRouting.swift`
- Modify: `FitGenius/Services/AIService.swift`
- Modify: `scripts/app-language-policy-tests.swift`

- [ ] Add assertions that current iOS routing uses `fitgenius-text`, `fitgenius-vision`, and `fitgenius-video` rather than provider names.
- [ ] Run the relevant Swift script and confirm the new assertions fail.
- [ ] Update routing constants and provider-specific comments without changing the mobile endpoint or authentication contract.
- [ ] Re-run Swift scripts and the generic iOS Simulator build.

### Task 4: Environment And Operations Documentation

**Files:**
- Modify: `.env.example`
- Modify: `backend/README.md`
- Modify: `README.md`
- Modify: `docs/agent-handoff.md`

- [ ] Document `AI_PROVIDER`, `MINIMAX_API_KEY`, `MINIMAX_ENDPOINT`, and `MINIMAX_MODEL` with no real values.
- [ ] Document legacy client compatibility, reasoning separation, rollback, and verified multimodal capabilities.
- [ ] Run a repository secret scan and confirm no MiniMax key appears in tracked or untracked workspace files.

### Task 5: Vercel Production Migration

**Files:**
- No repository secret files.

- [ ] Add/update MiniMax environment variables for Production, Preview, and Development using sensitive Vercel values.
- [ ] Set `AI_PROVIDER=minimax` and keep `ALIYUN_API_KEY` only as rollback configuration.
- [ ] Deploy to production and wait for READY.
- [ ] Verify the production `/api/ai/chat` authentication boundary still returns 401 without a FitGenius session.
- [ ] Use an authenticated session to validate text streaming and multimodal requests, then inspect runtime errors.

### Task 6: Versioned App Build And Release Preparation

**Files:**
- Modify only the intended version settings in `FitGenius.xcodeproj/project.pbxproj` after reconciling pre-existing local changes.
- Modify: `docs/agent-handoff.md`

- [ ] Confirm the current App Store marketing/build versions before changing them.
- [ ] Build and run the iOS app against production on Simulator; validate AI connection, text response, and UI startup.
- [ ] Archive the intended new version with full Xcode signing.
- [ ] Upload to App Store Connect/TestFlight when credentials and agreements permit.
- [ ] Record every automated validation and any remaining manual Apple review step in the handoff.
