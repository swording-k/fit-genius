# FitGenius Backend

This is the Phase 2 Vercel backend. It exposes the API surface that the iOS
app calls for Apple Sign in, AI chat proxying, and form-analysis history
sync.

## Endpoints

| Method | Path                 | Purpose                                                  | Auth required |
| ------ | -------------------- | -------------------------------------------------------- | ------------- |
| GET    | `/api/health`        | Health check.                                            | No            |
| POST   | `/api/form-analyses` | Sync a form-analysis record for the current user.        | Bearer token  |
| POST   | `/api/auth/apple`    | Exchange an Apple identityToken for a session JWT.       | None          |
| POST   | `/api/ai/chat`       | Proxy an OpenAI-compatible chat completion to Aliyun.    | Bearer token  |

`/api/ai/chat` forwards the request to
`https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` using
the server-side `ALIYUN_API_KEY`. The iOS app never sees the provider key.

## Required Environment Variables

Set these in the Vercel project dashboard (or in a local `.env` during
development). Never commit real values.

| Name                  | Required | Notes                                                                       |
| --------------------- | -------- | --------------------------------------------------------------------------- |
| `DATABASE_URL`        | Yes (prod) | Neon Postgres connection string. Apply `backend/schema.sql` first.        |
| `SESSION_SECRET`      | Yes (prod) | 32+ chars. Generate with `openssl rand -hex 32`.                           |
| `APPLE_BUNDLE_ID`     | Yes (prod) | Must match the iOS app bundle id (e.g. `com.swordingk.fitgenius`).          |
| `ALIYUN_API_KEY`      | Yes (prod) | Used by `/api/ai/chat`.                                                     |
| `SESSION_ISSUER`      | No        | Defaults to `fitgenius`. Keep stable across deployments.                    |
| `FITGENIUS_DEV_SYNC_TOKEN` | No    | Optional development bearer token for `/api/form-analyses`.                 |
| `BACKEND_PUBLIC_URL`  | No        | The public URL of this backend. Diagnostic only.                            |

## Local Checks

```bash
npm install
npm run test:backend
scripts/check-localization.sh
```

`npm run test:backend` runs every `backend/tests/*.test.mjs` file under
`node --test`. The suite covers payload validation, the repository SQL
builder, the `/api/form-analyses` handler, the Apple token verifier, the
session JWT helpers, the `/api/auth/apple` handler, and the
`/api/ai/chat` proxy.

## Database Setup

After creating a Neon project and setting `DATABASE_URL`, apply the
schema:

```bash
DATABASE_URL=postgres://... ./scripts/apply-schema.sh
# or
npm run db:migrate
```

The migration is idempotent because every statement in
`backend/schema.sql` uses `if not exists`.

## How iOS Uses the Backend

1. `AuthService.signInWithApple()` returns an `AppleSignInResult`
   containing the raw `identityToken`.
2. `AuthViewModel` calls
   `AppleAuthAPIClient.exchange(identityToken:userIdentifier:fullName:)`
   which POSTs to `/api/auth/apple`.
3. The backend verifies the Apple JWT against
   `https://appleid.apple.com/auth/keys` (JWKS cache: 1 hour via
   `jose.createRemoteJWKSet`) and upserts a row in `users`.
4. The backend returns a session JWT signed with `SESSION_SECRET`.
5. iOS stores the session token in `UserDefaults` via `SyncSettings`
   and uses it as a `Bearer` token for `/api/form-analyses` and
   `/api/ai/chat`.

## Security Notes

- Apple identity tokens are verified against Apple's published JWKS and
  are never stored on the server.
- Session tokens are HS256 JWTs with a 30-day TTL.
- The AI proxy uses the server-side `ALIYUN_API_KEY` so the key never
  appears in the iOS app bundle or in `git`.
- `users.email` is stored only when Apple returns it on the first
  sign-in; it is never refreshed from the client.
