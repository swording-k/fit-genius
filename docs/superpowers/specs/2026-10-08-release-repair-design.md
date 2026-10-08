# Release repair design

Owner approval: 2026-10-08 conversation approved the scoped repair order in
`docs/release-candidate-audit-2026-10-03.md`, then explicitly requested implementation.
No additional feature, merge, Store submission or media-rights change is included.

## Data continuity

An automatically created plan without days is not meaningful cloud data. A
first-sync device with no meaningful local content restores a remote snapshot;
existing manual days, profiles or diet/health records retain local priority.
Only HTTP404 means no remote data. Read, decode or transport failures abort the
sync without writing a snapshot or changing the local ownership baseline.
Already synchronized intentional deletions still upload rather than restore.
In-flight fetch must not discard local edits made while awaiting the network.

Large snapshots use authenticated, bounded chunks rather than public upload
URLs: 48 KiB raw bytes per base64 chunk, at most512 chunks/24MiB. PUT uses
`{snapshotUpload:{id,index,count,chunk}}`; only the complete upload changes the
current snapshot pointer. GET of a large snapshot returns
`{snapshotDownload:{id,count,sha256},updatedAt}`; GET `?download=id&chunk=N`
returns `{snapshotChunk:{id,index,count,chunk}}`. Client verifies completeness,
identity and SHA256 before decoding/restoring. Legacy small JSON remains valid.
This avoids gateway payload limits and new public storage permissions.

## AI and deletion

Missing proxy session and invalid generated JSON produce explicit existing
localized errors, never a generic personalized-plan substitute. Direct own-key
mode remains available. Candidate previews and explicit apply remain mandatory.

Authenticated deletion invalidates old sessions, deletes only that account's
snapshots/chunks/form analyses, then clears all local product models. Failed
cloud deletion preserves local data; missing cloud credentials cannot report
success. Reference exercise templates remain intact. Sync is suspended during
deletion so completion cannot reapply or recreate deleted data.

## Release delivery

Align Main/Widget/Watch version/build, inspect available uploaded-build evidence,
build Simulator and Release Archive, verify embedded versions and rights filter.
Do not submit/upload to Store. Secret values remain only in production environment;
deployment must preserve existing provider/session variables. User acceptance
of real Apple login, two-device restore, Photos comparison and Watch remains
distinct from automated tests/build proof.
