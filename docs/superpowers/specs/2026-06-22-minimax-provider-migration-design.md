# MiniMax Provider Migration Design

Date: 2026-06-22

## Goal

Move FitGenius AI traffic from Aliyun Qwen to MiniMax without breaking already
released iOS clients and without exposing a provider key to any app bundle.

## Verified Provider Contract

Live probes with the supplied MiniMax key verified:

- China endpoint: `https://api.minimaxi.com/v1/chat/completions`.
- Account-visible default model: `MiniMax-M3`.
- OpenAI-compatible text completion works.
- `image_url` data URLs work.
- `video_url` data URLs work.
- Streaming SSE works and closes the connection without necessarily emitting
  `[DONE]`; current iOS logic already accepts EOF.
- `reasoning_split: true` keeps reasoning in `reasoning_content` while final
  user text remains in `content`, which is compatible with current clients.

## Architecture

`/api/ai/chat` remains the only mobile-facing AI endpoint. The backend selects
an upstream provider from server-only environment variables and normalizes
mobile model aliases into provider model names.

Production defaults:

- `AI_PROVIDER=minimax`
- `MINIMAX_ENDPOINT=https://api.minimaxi.com/v1/chat/completions`
- `MINIMAX_MODEL=MiniMax-M3`
- `MINIMAX_API_KEY=<Vercel sensitive environment variable>`

The existing `ALIYUN_API_KEY` remains in Vercel temporarily for rollback, but
is not used while `AI_PROVIDER=minimax`.

## Compatibility

Released clients currently send `qwen3-omni-flash` or `qwen-vl-max`. The
backend maps both legacy names to `MINIMAX_MODEL`, so no App Store update is
required for the provider migration.

The new iOS build will send provider-neutral aliases:

- `fitgenius-text`
- `fitgenius-vision`
- `fitgenius-video`

The backend maps these aliases to the configured provider model as well.

Unknown model names from clients are not forwarded to MiniMax. They fall back
to the configured MiniMax model, preventing provider-name injection and stale
client failures.

## Request And Response Rules

- Preserve the current FitGenius session-token requirement.
- Preserve text, image, and video message content unchanged.
- Preserve streaming behavior.
- Add `reasoning_split: true` for MiniMax requests.
- Do not forward provider keys, endpoint details, or internal error bodies to
  app logs beyond the existing bounded upstream error detail.
- Non-streaming responses remain wrapped as `{ ok: true, data }`.
- Streaming SSE is passed through unchanged; clients consume only
  `delta.content`.

## Rollback

Changing only `AI_PROVIDER=aliyun` and redeploying restores the previous Qwen
route. No mobile release is required for rollback.

## Validation

1. Backend unit tests cover MiniMax endpoint, model mapping, reasoning split,
   multimodal passthrough, legacy Aliyun rollback, and missing configuration.
2. Full backend suite passes.
3. Generic iOS Simulator build passes.
4. Production deployment reaches READY.
5. Authenticated production probes cover streaming text and multimodal input.
6. Runtime logs are checked for provider errors without exposing secrets.

## Security

- The MiniMax key is entered directly into Vercel as a sensitive variable.
- The key is never written to a repository file, shell command argument, test
  fixture, app plist, build setting, or documentation.
- Because the key was shared in chat, rotate it in MiniMax after production
  validation and replace the Vercel value with the rotated key.
